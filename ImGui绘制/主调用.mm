typedef struct __IOHIDEvent* IOHIDEvent;
typedef struct __IOHIDNotification* IOHIDNotification;
typedef struct __IOHIDService* IOHIDService;
typedef struct __GSEvent* GSEvent;

extern "C" {
    void GSInitialize();
    void UIApplicationInitialize();
    void BKSDisplayServicesStart();
    void GSEventPushRunLoopMode(CFStringRef mode);
    void GSEventInitialize(Boolean registerPurple);
    void UIApplicationInstantiateSingleton(id aclass);
    void *BKSHIDEventRegisterEventCallback(void (*)(void *, void *, IOHIDService, IOHIDEvent));
};

@interface UIApplication (Private)
- (void)_accessibilityInit;
- (void)__completeAndRunAsPlugin;
- (void)_enqueueHIDEvent:(IOHIDEvent)IOHIDEvent;
@end

static __used void 创建应用函数(void*, void*, IOHIDService IOHIDService, IOHIDEvent IOHIDEvent) {
    static UIApplication* 应用 = [UIApplication sharedApplication];
    [应用 _enqueueHIDEvent:IOHIDEvent];
};

static NSString* 本地存储进程名() {
    static dispatch_once_t onceToken;
    static NSString* 进程名 = nil;
    dispatch_once(&onceToken, ^{
        static NSString* 本地路径 = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        进程名 = [本地路径 stringByAppendingPathComponent:@"ImGui绘制(PID)"];
    });
    return 进程名;
};

int main(int Argc, char* Argv[]) {
    @autoreleasepool {
        if (Argc <= 1) {
            return UIApplicationMain(Argc, Argv, @"应用", @"应用挂载方法");
        };
        
        if (strcmp(Argv[1], "开启图层") == 0) {
            NSString* 进程ID = [NSString stringWithFormat:@"%d", getpid()];
            [进程ID writeToFile:本地存储进程名() atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [UIScreen initialize];
            CFRunLoopGetCurrent();
            GSInitialize();
            BKSDisplayServicesStart();
            UIApplicationInitialize();
            [NSRunLoop currentRunLoop];
            BKSHIDEventRegisterEventCallback(创建应用函数);
            if (@available(iOS 15.0, *)) {
                GSEventInitialize(0);
                GSEventPushRunLoopMode(kCFRunLoopDefaultMode);
            };
            UIApplicationInstantiateSingleton(objc_getClass("HUD"));
            static id<UIApplicationDelegate> HUD挂载方法 = [[objc_getClass("HUD挂载方法") alloc] init];
            [UIApplication.sharedApplication setDelegate:HUD挂载方法];
            [UIApplication.sharedApplication _accessibilityInit];
            [UIApplication.sharedApplication __completeAndRunAsPlugin];
            CFRunLoopRun();
        } else {
            NSString* 进程名 = [NSString stringWithContentsOfFile:本地存储进程名() encoding:NSUTF8StringEncoding error:nil];
            if (进程名) {
                pid_t 进程ID = (pid_t)[进程名 intValue];
                if (strcmp(Argv[1], "关闭图层") == 0) {
                    kill(进程ID, SIGKILL);
                    unlink(本地存储进程名().UTF8String);
                } else if (strcmp(Argv[1], "结束进程") == 0) {
                    int 判断 = kill(进程ID, 0);
                    if (判断 == 0) {
                        return EXIT_FAILURE;
                    };
                };
            };
        };
        return EXIT_SUCCESS;
    };
};
