//
//  BCei
//
//  Created by Ailin 33438904 on 2025/12/3.
//
#import <spawn.h>
#import <sys/wait.h>
#import <mach-o/dyld.h>
#import <malloc/_malloc.h>
#import <sys/_types/_uid_t.h>

#import "绘制/HUD视图控制器.h"

extern "C" {
    char** 环境变量;
    int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
    int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
    int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);
};

OBJC_EXTERN bool 关闭HUD标识符();
bool 关闭HUD标识符() {
    static char* 路径名 = nullptr;
    uint32_t 路径名长度 = 0;
    _NSGetExecutablePath(nullptr, &路径名长度);
    路径名 = (char*)calloc(1, 路径名长度);
    _NSGetExecutablePath(路径名, &路径名长度);
    
    posix_spawnattr_t 进程;
    posix_spawnattr_init(&进程);
    
    posix_spawnattr_set_persona_np(&进程, 99, 1);
    posix_spawnattr_set_persona_uid_np(&进程, 0);
    posix_spawnattr_set_persona_gid_np(&进程, 0);

    pid_t 进程ID;
    const char* 命令行参数[] = {路径名, "结束进程", nullptr};
    posix_spawn(&进程ID, 路径名, nullptr, &进程, (char**)命令行参数, 环境变量);
    posix_spawnattr_destroy(&进程);

    int 退出状态;
    waitpid(进程ID, &退出状态, 0);
    return WEXITSTATUS(退出状态) != 0;
};

OBJC_EXTERN void 开启或关闭HUD(bool 标识符);
void 开启或关闭HUD(bool 标识符) {
    static char* 路径名 = nullptr;
    uint32_t 路径名长度 = 0;
    _NSGetExecutablePath(nullptr, &路径名长度);
    路径名 = (char*)calloc(1, 路径名长度);
    _NSGetExecutablePath(路径名, &路径名长度);
    
    posix_spawnattr_t 进程;
    posix_spawnattr_init(&进程);
    
    posix_spawnattr_set_persona_np(&进程, 99, 1);
    posix_spawnattr_set_persona_uid_np(&进程, 0);
    posix_spawnattr_set_persona_gid_np(&进程, 0);
    
    pid_t 进程ID;
    if (标识符) {
        posix_spawnattr_setpgroup(&进程, 0);
        posix_spawnattr_setflags(&进程, POSIX_SPAWN_SETPGROUP);

        const char* 命令行参数[] = {路径名, "开启图层", nullptr};
        posix_spawn(&进程ID, 路径名, nullptr, &进程, (char**)命令行参数, 环境变量);
        posix_spawnattr_destroy(&进程);
    } else {
        const char* 命令行参数[] = {路径名, "关闭图层", nullptr};
        posix_spawn(&进程ID, 路径名, nullptr, &进程, (char**)命令行参数, 环境变量);
        posix_spawnattr_destroy(&进程);
        
        int 退出状态;
        waitpid(进程ID, &退出状态, 0);
    };
};

@interface UIApplication (Private)
- (void)suspend;
- (void)terminateWithSuccess;
@end

@interface UIWindow (Private)
- (unsigned int)_contextId;
@end

@interface HUD : UIApplication

@end

@implementation HUD

@end

@interface 窗口 : UIWindow

@end

@implementation 窗口

- (BOOL)_ignoresHitTest { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }

@end

@interface 注册图层方法 : NSObject
- (void) registerWindowWithContextID:(unsigned)标识符 atLevel:(double)窗口等级;
@end

@interface HUD挂载方法 : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) 窗口* 窗口;
@property (nonatomic, strong) NSMethodSignature* NSMethodSignature;
@property (nonatomic, strong) NSInvocation* NSInvocation;
@end

@implementation HUD挂载方法

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions {
    self.窗口 = [[窗口 alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.窗口.backgroundColor = UIColor.clearColor;
    self.窗口.rootViewController = [[HUD视图控制器 alloc] init];
    self.窗口.windowLevel = UIWindowLevelNormal + 1;
    [self.窗口 makeKeyAndVisible];

    注册图层方法* 图层方法 = [[objc_getClass("SBSAccessibilityWindowHostingController") alloc] init];
    int _contextId = [self.窗口 _contextId];
    double windowLevel = [self.窗口 windowLevel];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    self.NSMethodSignature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
    self.NSInvocation = [NSInvocation invocationWithMethodSignature:self.NSMethodSignature];
    
    [self.NSInvocation setTarget:图层方法];
    [self.NSInvocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
    [self.NSInvocation setArgument:&_contextId atIndex:2];
    [self.NSInvocation setArgument:&windowLevel atIndex:3];
    [self.NSInvocation invoke];
#pragma clang diagnostic pop
    
    return YES;
};

@end
