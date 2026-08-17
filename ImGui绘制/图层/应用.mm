//
//  BCei
//
//  Created by Ailin 33438904 on 2025/12/3.
//
#import <UIKit/UIKit.h>

#import "ImGui绘制-Swift.h"

OBJC_EXTERN bool 关闭HUD标识符();
OBJC_EXTERN void 开启或关闭HUD(bool 标识符);

@interface 应用 : UIApplication
@end
@implementation 应用
@end

@interface 应用视图控制器 : UIViewController <ModernUIDelegate>
@end

@implementation 应用视图控制器

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    bool HUD是否已开启 = 关闭HUD标识符();

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    bool 自瞄开关 = [defs objectForKey:@"自瞄开关"] ? [defs boolForKey:@"自瞄开关"] : YES;

    NSDictionary *uiConfig = @{
        @"drawEnabled": @(HUD是否已开启),
        @"aimbotEnabled": @(自瞄开关),
    };

    UIViewController *swiftVC = [ModernUIBridge createControlCenterWithDict:uiConfig delegate:self];

    [self addChildViewController:swiftVC];
    swiftVC.view.frame = self.view.bounds;
    swiftVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:swiftVC.view];
    [swiftVC didMoveToParentViewController:self];
}

- (void)onToggleDrawWithIsOn:(BOOL)isOn {
    bool 标识符 = 关闭HUD标识符();
    if (isOn == 标识符) return;
    开启或关闭HUD(isOn);
}

- (void)onToggleAimbotWithIsOn:(BOOL)isOn {
    // 自瞄开关写入 UserDefaults（HUD 进程每帧读取）
    [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:@"自瞄开关"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@interface 应用挂载方法 : UIResponder <UIApplicationDelegate, UISceneDelegate>
@property (nonatomic, strong) UIWindow* 窗口;
@end

@implementation 应用挂载方法

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions {
    self.窗口 = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.窗口.backgroundColor = UIColor.clearColor;
    self.窗口.rootViewController = [[应用视图控制器 alloc] init];
    [self.窗口 makeKeyAndVisible];
    return YES;
};

@end
