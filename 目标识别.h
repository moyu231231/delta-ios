// 目标识别.h —— 用 CoreML 识别屏幕上的敌人（三角洲公益模型：head/body 头身分离）
//
// 注意：苹果 Vision 框架没有内置的通用目标检测 API（只有人脸/文字/矩形检测），
//       所以必须用 VNCoreMLRequest 加载自定义模型（三角洲 best.mlpackage，cls0=body/cls1=head）。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 一个识别目标
@interface Target : NSObject
@property (nonatomic, assign) CGRect boundingBox;   // 归一化 (0~1)，原点左下角
@property (nonatomic, assign) float confidence;      // 置信度 0~1
@property (nonatomic, copy)   NSString *label;       // 类别标签（"body" / "head"）
@property (nonatomic, assign) BOOL isHead;           // 是否是「头部」框（三角洲模型 cls1=head）
@end

@interface TargetDetector : NSObject

/// 用自定义 CoreML 模型（传模型名，如 "best"，不含扩展名）
+ (instancetype)detectorWithCoreMLModel:(NSString *)mlmodelName;

/// 识别一张图里的所有目标（同步返回，主循环在后台线程调用）
- (NSArray<Target *> *)detectInImage:(UIImage *)image;

/// 检测器是否就绪（模型加载成功）
- (BOOL)isReady;

@end

NS_ASSUME_NONNULL_END
