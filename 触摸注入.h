// 触摸注入.h —— 跨进程触摸注入（模拟手指拖动，注入到前台游戏）
// 原理：通过 IOHIDEvent 私有 API 在系统 HID 层创建触摸事件，
//       让系统以为是真实手指触摸 → 路由给前台 App（游戏）。
//       全程不碰游戏进程内存，tersafe 的 task port / 注入 / hook 检测全部失效。
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface TouchInjector : NSObject

/// 初始化：动态加载 IOHIDEvent 私有 API（dlopen + dlsym，不链接私有 framework）
/// 返回 NO 表示当前设备不支持（需 root/巨魔权限）
+ (BOOL)setup;

/// 手指按下
+ (void)touchDownAt:(CGPoint)point;

/// 手指移动到新位置（拖动瞄准）
+ (void)touchMoveTo:(CGPoint)point;

/// 手指抬起
+ (void)touchUpAt:(CGPoint)point;

/// 点击（按下 + 立即抬起）
+ (void)tapAt:(CGPoint)point;

/// 拖动：从 A 平滑移动到 B（用于瞄准移动）
/// @param from 起点（屏幕坐标）
/// @param to 终点（屏幕坐标）
/// @param duration 持续时间（秒），越小越快
+ (void)dragFrom:(CGPoint)from to:(CGPoint)to duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
