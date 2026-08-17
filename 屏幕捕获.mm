// 屏幕捕获.mm —— 截屏实现
//
// 方案优先级：
//   1. _UICreateScreenUIImage()（UIKit 私有 API，直接读 framebuffer，root 可用，无提示）
//   2. UIGraphicsBeginImageContext + 主窗口 layer 渲染（仅限本 App，游戏画面取不到，备用）
//
// ⚠️ 说明：_UICreateScreenUIImage 是 UIKit 未公开导出符号，通过 dlsym 动态获取。
//    纯巨魔（root）环境可截取整个屏幕；若返回空/仅本 App 画面，
//    则需改用 ReplayKit（见 README 的 ReplayKit 方案）。

#import "屏幕捕获.h"
#import <dlfcn.h>

// UIKit 私有 API 声明（动态获取，不链接）
typedef UIImage *(*UICreateScreenUIImage_t)(void);

@implementation ScreenCapture

+ (BOOL)privateCaptureAvailable {
    static dispatch_once_t onceToken;
    static BOOL avail = NO;
    dispatch_once(&onceToken, ^{
        void *uikit = dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_LAZY);
        if (uikit) {
            UICreateScreenUIImage_t fn = (UICreateScreenUIImage_t)dlsym(uikit, "_UICreateScreenUIImage");
            avail = (fn != NULL);
        }
    });
    return avail;
}

+ (UIImage *)capture {
    // 优先：UIKit 私有截屏 API
    if ([self privateCaptureAvailable]) {
        void *uikit = dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_LAZY);
        UICreateScreenUIImage_t fn = (UICreateScreenUIImage_t)dlsym(uikit, "_UICreateScreenUIImage");
        if (fn) {
            UIImage *img = fn();
            if (img && img.size.width > 1) {
                return img;
            }
        }
    }
    // 回退：本 App 窗口截图（游戏画面取不到，仅作降级）
    return [self _captureOwnWindow];
}

+ (UIImage *)_captureOwnWindow {
    UIWindow *window = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { window = w; break; }
    }
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) return nil;

    UIGraphicsBeginImageContextWithOptions(window.bounds.size, NO, [UIScreen mainScreen].scale);
    [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
