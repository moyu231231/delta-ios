// main.mm —— AI 自瞄入口（对齐能跑的神之眼巨魔/ImGui绘制的启动方式）
// 关键：能跑的都用「自定义 UIApplication 子类」作为 principal class，我改成一致。
#import <UIKit/UIKit.h>
#import "悬浮球.h"

// 自定义 UIApplication 子类（对齐能跑的神之眼巨魔 @"MainApplication" / ImGui绘制 @"应用"）
@interface 应用 : UIApplication
@end
@implementation 应用
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 设置主窗口（对齐能跑的 didFinishLaunching：window + rootViewController + makeKeyAndVisible）
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor clearColor];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];

    // 只显示悬浮球，不做其他初始化（避免启动闪退）
    [FloatingBall show];

    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        // principal class 用自定义 UIApplication 子类（对齐能跑的），不用系统 UIApplication
        return UIApplicationMain(argc, argv, @"应用", NSStringFromClass([AppDelegate class]));
    }
}
