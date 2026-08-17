// main.mm —— AI 自瞄入口（稳定版）
// 关键设计：启动时只做最安全的事（设置 window + 显示悬浮球），
//           所有私有 API（触摸注入/模型加载/屏幕捕获）延迟到用户点悬浮球开启自瞄时才初始化。
//           这样即使某个私有 API 崩溃，也只在开启时崩，App 打开不会闪退。
#import <UIKit/UIKit.h>
#import "悬浮球.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 设置主窗口（传统 AppDelegate 模式，必须手动设置 window，否则黑屏）
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.backgroundColor = [UIColor clearColor];
    [self.window makeKeyAndVisible];

    // 只显示悬浮球，不做任何其他初始化（避免启动闪退）
    [FloatingBall show];

    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, @"UIApplication", NSStringFromClass([AppDelegate class]));
    }
}
