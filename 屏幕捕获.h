// 屏幕捕获.h —— 截取当前屏幕画面（供 YOLO/Vision 识别敌人）
// 纯巨魔（root 不越狱）优先用 _UICreateScreenUIImage（UIKit 私有 API，无录屏提示），
// 失败回退 ReplayKit RPScreenRecorder（系统录屏，有提示）。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenCapture : NSObject

/// 截取当前屏幕（返回整个屏幕的 UIImage，非本 App 画面）
/// 失败返回 nil
+ (nullable UIImage *)capture;

/// 是否可用（_UICreateScreenUIImage 是否加载成功）
+ (BOOL)privateCaptureAvailable;

@end

NS_ASSUME_NONNULL_END
