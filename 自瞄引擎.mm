// 自瞄引擎.mm —— AI 自瞄主循环实现
//
// 流程（后台线程循环）：
//   1. 截屏（ScreenCapture）
//   2. 识别敌人（TargetDetector，Vision/CoreML）
//   3. 选最佳目标（FOV 内、离准星最近）
//   4. 计算瞄准点（头部 = boundingBox 顶部中心，胸部 = 中心）
//   5. 换算手指滑动距离（偏移 / 灵敏度）
//   6. 在屏幕右半屏模拟滑动（TouchInjector）
//
// ⚠️ 灵敏度 sensitivity 是唯一需要真机校准的硬参数：
//    准星偏多少 → 手指滑多少。不同游戏/灵敏度设置不同，实测调。

#import "自瞄引擎.h"
#import "屏幕捕获.h"
#import "目标识别.h"
#import "触摸注入.h"
#include <unistd.h>

@interface AimbotEngine ()
@property (nonatomic, strong) TargetDetector *detector;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, assign) BOOL running;
@end

// 私有方法声明（避免 ARC 下未声明警告）
@interface AimbotEngine (Private)
- (Target *)_bestTarget:(NSArray<Target *> *)targets pixelSize:(CGSize)pixelSize;
- (CGPoint)_aimPointForTarget:(Target *)t pixelSize:(CGSize)pixelSize;
@end

@implementation AimbotEngine

+ (instancetype)shared {
    static AimbotEngine *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[AimbotEngine alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 默认参数
        _enabled = YES;
        _sensitivity = 1.0f;
        _fovRadius = 400.0f;
        _aimAtHead = YES;
        _smoothness = 0.6f;
        _detectInterval = 1;
        _minConfidence = 0.4f;
        _running = NO;
        // 模型延迟加载：不在 init 里加载，等 start() 时才加载（避免启动闪退）
        _detector = nil;
    }
    return self;
}

- (void)start {
    if (self.running) return;
    // 延迟加载三角洲模型（首次开启自瞄时才加载，避免 App 启动时加载崩溃）
    if (!_detector) {
        _detector = [TargetDetector detectorWithCoreMLModel:@"best"];
        if (![_detector isReady]) {
            NSLog(@"[AI自瞄] 警告：best 模型加载失败，自瞄不可用");
        }
    }
    self.running = YES;
    self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(_mainLoop) object:nil];
    self.thread.name = @"AimbotEngine";
    [self.thread start];
}

- (void)stop {
    self.running = NO;
}

- (void)_mainLoop {
    int frame = 0;
    while (self.running) {
        @autoreleasepool {
            frame++;

            // 按间隔识别（省电，不必每帧全屏识别）
            BOOL shouldDetect = (frame % MAX(self.detectInterval, 1)) == 0;
            if (shouldDetect && self.enabled) {
                [self _processFrame];
            }
        }
        // 循环间隔 ~33ms（约 30 FPS）
        usleep(33000);
    }
}

- (void)_processFrame {
    // 1. 截屏
    UIImage *frame = [ScreenCapture capture];
    if (!frame) return;

    // 2. 识别敌人（三角洲模型输出 head/body 两类）
    NSArray<Target *> *targets = [self.detector detectInImage:frame];
    if (targets.count == 0) return;

    // Vision 的 boundingBox 基于 CGImage「像素」尺寸，这里用像素尺寸做换算
    CGFloat scale = frame.scale > 0 ? frame.scale : [UIScreen mainScreen].scale;
    CGSize pixelSize = CGSizeMake(frame.size.width * scale, frame.size.height * scale);

    // 3. 选最佳目标
    Target *best = [self _bestTarget:targets pixelSize:pixelSize];
    if (!best) return;

    // 4. 计算瞄准点（屏幕点坐标，原点左上角）
    CGPoint aimPoint = [self _aimPointForTarget:best pixelSize:pixelSize];
    if (aimPoint.x < 0 || aimPoint.y < 0) return;

    // 5. 计算相对屏幕中心的偏移
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGPoint center = CGPointMake(screenSize.width / 2.0, screenSize.height / 2.0);

    CGFloat dx = aimPoint.x - center.x;
    CGFloat dy = aimPoint.y - center.y;
    CGFloat dist = sqrtf(dx * dx + dy * dy);

    // FOV 判定：离准星太远的不瞄
    if (dist > self.fovRadius) return;

    // 6. 换算成手指滑动距离（灵敏度 + 平滑）
    CGFloat moveX = dx / self.sensitivity * self.smoothness;
    CGFloat moveY = dy / self.sensitivity * self.smoothness;

    // 7. 在屏幕右半屏模拟滑动（FPS 手游右半屏控制视角）
    //    起点：右半屏中心偏下（避开准星和开火键）
    CGPoint start = CGPointMake(screenSize.width * 0.75, screenSize.height * 0.65);
    CGPoint end = CGPointMake(start.x + moveX, start.y + moveY);

    // 短拖动（越平滑越像真人）
    [TouchInjector dragFrom:start to:end duration:0.05];
}

// 选最佳目标：置信度够高 + 离屏幕中心最近
// 锁头模式：优先选「头部」框（head），没有 head 框才用 body 框顶部估算
- (Target *)_bestTarget:(NSArray<Target *> *)targets pixelSize:(CGSize)pixelSize {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGPoint center = CGPointMake(screenSize.width / 2.0, screenSize.height / 2.0);

    // 过滤置信度
    NSMutableArray<Target *> *valid = [NSMutableArray array];
    for (Target *t in targets) {
        if (t.confidence >= self.minConfidence) [valid addObject:t];
    }
    if (valid.count == 0) return nil;

    // 锁头：优先 head 框
    NSArray<Target *> *pool = valid;
    if (self.aimAtHead) {
        NSPredicate *headPred = [NSPredicate predicateWithFormat:@"isHead == YES"];
        NSArray<Target *> *heads = [valid filteredArrayUsingPredicate:headPred];
        if (heads.count > 0) pool = heads;   // 有 head 框就用 head 框，没有才用 body
    }

    Target *best = nil;
    CGFloat bestDist = CGFLOAT_MAX;
    for (Target *t in pool) {
        // 归一化 boundingBox（原点左下角）→ 屏幕点坐标（原点左上角）
        CGPoint aim = [self _aimPointForTarget:t pixelSize:pixelSize];
        if (aim.x < 0 || aim.y < 0) continue;

        CGFloat dx = aim.x - center.x;
        CGFloat dy = aim.y - center.y;
        CGFloat d = sqrtf(dx * dx + dy * dy);
        if (d < bestDist) {
            bestDist = d;
            best = t;
        }
    }
    return best;
}

// 计算瞄准点：头部 = boundingBox 顶部中心，胸部 = boundingBox 中心
// 输入归一化 boundingBox（原点左下角，相对像素尺寸），输出屏幕点坐标（原点左上角）
- (CGPoint)_aimPointForTarget:(Target *)t pixelSize:(CGSize)pixelSize {
    CGRect b = t.boundingBox;
    if (CGRectIsEmpty(b)) return CGPointMake(-1, -1);

    CGFloat centerX = CGRectGetMidX(b);   // 归一化中心 x
    CGFloat topY = CGRectGetMaxY(b);      // 顶部（左下角坐标系里的最大 y）
    CGFloat midY = CGRectGetMidY(b);      // 中心 y

    CGFloat aimNormX = centerX;
    CGFloat aimNormY;
    if (self.aimAtHead) {
        if (t.isHead) {
            aimNormY = midY;   // head 框：瞄中心（框本身就框着头部）
        } else {
            aimNormY = topY;   // body 框：瞄顶部（头部在身体顶部）
        }
    } else {
        aimNormY = midY;       // 锁身体：瞄中心
    }

    // 归一化 → 像素坐标（y 翻转：屏幕原点左上角）
    CGFloat px_pixel = aimNormX * pixelSize.width;
    CGFloat py_pixel = (1.0 - aimNormY) * pixelSize.height;

    // 像素 → 点（触摸注入用点坐标）
    CGFloat scale = [UIScreen mainScreen].scale;
    if (scale <= 0) scale = 2.0;
    return CGPointMake(px_pixel / scale, py_pixel / scale);
}

- (void)triggerOnce {
    if (self.running) {
        [self _processFrame];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self _processFrame];
        });
    }
}

@end
