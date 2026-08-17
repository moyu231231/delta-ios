//
//  BCei
//
//  Created by Ailin 33438904 on 2025/12/3.
//
#import <UIKit/UIKit.h>

#import "ImGui绘制-Swift.h"
#import <sys/sysctl.h>
#import <string.h>
#import <stdlib.h>

// 检查游戏进程是否在运行
static bool 检查游戏进程(const char *进程名) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t len = 0;
    if (sysctl(mib, 4, nullptr, &len, nullptr, 0) < 0) return false;
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(len);
    if (!procs) return false;
    if (sysctl(mib, 4, procs, &len, nullptr, 0) < 0) { free(procs); return false; }
    bool 找到 = false;
    for (size_t i = 0, n = len / sizeof(struct kinfo_proc); i < n; i++) {
        if (strcmp(procs[i].kp_proc.p_comm, 进程名) == 0) { 找到 = true; break; }
    }
    free(procs);
    return 找到;
}

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
    bool 游戏在运行 = 检查游戏进程("DeltaForceClient");

    NSArray *状态列表 = @[
        @"① 先打开游戏（三角洲）进对局",
        @"② 再回来打开下方「绘制总开关」",
        游戏在运行 ? @"✅ 游戏已检测到" : @"⚠️ 游戏未运行",
        HUD是否已开启 ? @"✅ 绘制已开启" : @"绘制未开启",
    ];

    NSDictionary *uiConfig = @{
        @"drawEnabled": @(HUD是否已开启),
        @"状态列表": 状态列表,
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
