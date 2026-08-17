// 自瞄引擎.h —— AI 自瞄主循环（截屏 → 识别 → 选目标 → 拖动瞄准 → 触摸注入）
//
// 原理：FPS 手游视角由「右半屏手指滑动」控制。识别到敌人后，
//       计算敌人头部与屏幕中心（准星）的像素偏移，按灵敏度换算成手指滑动距离，
//       在屏幕右半屏模拟滑动，让视角转向敌人。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AimbotEngine : NSObject

+ (instancetype)shared;

// —— 可配置参数 ——
@property (nonatomic, assign) BOOL    enabled;        // 总开关
@property (nonatomic, assign) float   sensitivity;    // 灵敏度：屏幕 1 像素偏移 → 手指滑动多少像素（1.0 起步，真机校准）
@property (nonatomic, assign) float   fovRadius;      // FOV 半径（屏幕像素）：目标离准星多少像素内才瞄准（默认 400）
@property (nonatomic, assign) BOOL    aimAtHead;      // YES=锁头 NO=锁胸（默认 YES）
@property (nonatomic, assign) float   smoothness;     // 平滑度：单次拖动比例 0~1（越小越稳，默认 0.6）
@property (nonatomic, assign) int     detectInterval; // 识别间隔（帧）：每 N 次循环识别一次（默认 1）
@property (nonatomic, assign) float   minConfidence;  // 最低置信度阈值（默认 0.4）

// 启动 / 停止主循环（后台线程）
- (void)start;
- (void)stop;

// 手动触发一次瞄准（供调试）
- (void)triggerOnce;

// 当前是否在瞄准中
@property (nonatomic, readonly) BOOL running;

@end

NS_ASSUME_NONNULL_END
