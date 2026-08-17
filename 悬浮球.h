// 悬浮球.h —— 极简悬浮开关（拖动 + 点击开关自瞄 + 长按退出）
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FloatingBall : NSObject
+ (void)show;   // 显示悬浮球
+ (void)hide;   // 隐藏
@end

NS_ASSUME_NONNULL_END
