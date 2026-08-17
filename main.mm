// main.mm —— AI 自瞄入口
// 启动 → 初始化自瞄引擎 + 触摸注入 → 显示悬浮球 → 进入游戏后点悬浮球开启自瞄
#import <UIKit/UIKit.h>
#import "自瞄引擎.h"
#import "触摸注入.h"
#import "悬浮球.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 设置主窗口（无 scene manifest 的传统 AppDelegate 模式，必须手动设置 window，否则黑屏）
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.backgroundColor = [UIColor clearColor];
    [self.window makeKeyAndVisible];

    // 初始化触摸注入（动态加载 IOHIDEvent 私有 API）
    BOOL touchOK = [TouchInjector setup];
    NSLog(@"[AI自瞄] 触摸注入%@", touchOK ? @"就绪" : @"失败（需 root/巨魔）");

    // 初始化自瞄引擎（默认内置 Vision 识别）
    AimbotEngine *engine = [AimbotEngine shared];
    engine.enabled = NO;   // 默认关，进游戏后点悬浮球开启
    engine.sensitivity = 1.0f;   // ⚠️ 真机校准：准星偏 1px → 手指滑 1px（先试 1.0，再微调）
    engine.fovRadius = 400.0f;   // 准星 400px 内的敌人才瞄
    engine.aimAtHead = YES;      // 锁头
    [engine start];

    // 显示悬浮球
    [FloatingBall show];

    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, @"UIApplication", NSStringFromClass([AppDelegate class]));
    }
}
