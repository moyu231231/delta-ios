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
#import <objc/runtime.h>
#import <objc/message.h>

// 游戏进程名 + bundle ID（自动启动游戏用）
#define 游戏进程名 "DeltaForceClient"
#define 游戏BundleID @"com.proximabeta.deltaforce"   // ← 三角洲的 bundle ID，如果不对改成你的

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

- (void)onDeploy {
    // 一键部署：检查游戏 → 自动启动游戏 → 启动 HUD（自动跑内核漏洞 + 初始化内核读取 + 绘制 + 自瞄）
    bool 游戏在运行 = 检查游戏进程(游戏进程名);

    if (!游戏在运行) {
        // 自动启动游戏（运行时动态调用 LSApplicationWorkspace，避免链接私有框架）
        BOOL 启动成功 = NO;
        Class wsClass = objc_getClass("LSApplicationWorkspace");
        if (wsClass) {
            id workspace = [wsClass performSelector:@selector(defaultWorkspace)];
            if (workspace) {
                BOOL (*func)(id, SEL, id) = (BOOL (*)(id, SEL, id))[workspace methodForSelector:@selector(openApplicationWithBundleID:)];
                启动成功 = func(workspace, @selector(openApplicationWithBundleID:), 游戏BundleID);
            }
        }
        if (!启动成功) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"部署失败"
                message:@"❌ 无法自动启动游戏\n请手动打开三角洲进对局" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        // 等游戏启动
        sleep(5);
    }

    // 启动 HUD（HUD 自动跑内核漏洞 + 初始化内核读取 + 绘制 + 自瞄）
    开启或关闭HUD(true);

    // 弹成功提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"部署成功"
        message:@"✅ 环境已部署\n正在初始化内核...\n去游戏看白色准星圈是否出现" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
