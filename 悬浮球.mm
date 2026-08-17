// 悬浮球.mm —— 极简悬浮开关（稳定版）
// 关键设计：点击开关时，才初始化触摸注入 + 启动自瞄引擎（延迟初始化，避免启动闪退）
#import "悬浮球.h"
#import "自瞄引擎.h"
#import "触摸注入.h"

@interface FloatingBall ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *ball;
@end

@implementation FloatingBall

+ (void)show {
    static FloatingBall *ball = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ball = [[FloatingBall alloc] init];
    });
    [ball _setup];
}

- (void)_setup {
    CGRect screen = [UIScreen mainScreen].bounds;
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(screen.size.width - 80, 200, 60, 60)];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = [UIColor clearColor];

    self.ball = [UIButton buttonWithType:UIButtonTypeCustom];
    self.ball.frame = self.window.bounds;
    self.ball.layer.cornerRadius = 30;
    self.ball.backgroundColor = [UIColor colorWithRed:0 green:0.8 blue:1 alpha:0.7];
    self.ball.layer.borderColor = [UIColor whiteColor].CGColor;
    self.ball.layer.borderWidth = 2;
    self.ball.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.ball setTitle:@"自瞄" forState:UIControlStateNormal];
    [self.ball setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_onPan:)];
    [self.ball addGestureRecognizer:pan];

    [self.ball addTarget:self action:@selector(_onTap) forControlEvents:UIControlEventTouchUpInside];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_onLongPress)];
    lp.minimumPressDuration = 1.5;
    [self.ball addGestureRecognizer:lp];

    [self.window addSubview:self.ball];
    self.window.hidden = NO;
}

- (void)_onPan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    CGPoint translation = [pan translationInView:view.superview];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    view.center = center;
    [pan setTranslation:CGPointZero inView:view.superview];
}

- (void)_onTap {
    AimbotEngine *e = [AimbotEngine shared];

    if (!e.running) {
        // 首次开启：延迟初始化触摸注入 + 启动自瞄引擎（关键：不在 App 启动时做，避免闪退）
        BOOL touchOK = [TouchInjector setup];
        NSLog(@"[AI自瞄] 触摸注入%@", touchOK ? @"就绪" : @"失败（需 root/巨魔）");
        [e start];
        e.enabled = YES;
    } else {
        e.enabled = !e.enabled;   // 已启动，只切换开关
    }

    [self.ball setTitle:e.enabled ? @"自瞄✓" : @"自瞄✗" forState:UIControlStateNormal];
    self.ball.backgroundColor = e.enabled ?
        [UIColor colorWithRed:0 green:0.8 blue:0.4 alpha:0.8] :
        [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.7];
}

- (void)_onLongPress {
    exit(0);
}

+ (void)hide {
    // 无操作，悬浮球常驻
}

@end
