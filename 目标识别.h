// 目标识别.h —— 用 Vision/CoreML 识别屏幕上的敌人
//
// 两档方案：
//   1. 内置 Vision（VNRecognizeObjectsRequest）—— 无需模型文件，能识别人/物体，开箱即用（精度一般）
//   2. 自定义 YOLO CoreML（VNCoreMLRequest）—— 用户提供 .mlmodel，专训敌人模型（精度高，推荐）
//
// 返回的 Target 用「归一化 boundingBox」（原点左下角，0~1），引擎层负责转屏幕坐标。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 一个识别目标
@interface Target : NSObject
@property (nonatomic, assign) CGRect boundingBox;   // 归一化 (0~1)，原点左下角
@property (nonatomic, assign) float confidence;      // 置信度 0~1
@property (nonatomic, copy)   NSString *label;       // 类别标签（如 "person" / "head" / "body"）
@property (nonatomic, assign) BOOL isHead;           // 是否是「头部」框（三角洲模型 cls1=head）
@end

@interface TargetDetector : NSObject

/// 使用内置 Vision 模型（开箱即用）
+ (instancetype)builtInDetector;

/// 使用自定义 CoreML 模型（传 .mlmodel 文件名，不含扩展名）
+ (instancetype)detectorWithCoreMLModel:(NSString *)mlmodelName;

/// 识别一张图里的所有目标（同步返回，主循环在后台线程调用）
- (NSArray<Target *> *)detectInImage:(UIImage *)image;

/// 只保留「人」类目标（过滤掉车辆/物品等）
- (NSArray<Target *> *)detectPersonsInImage:(UIImage *)image;

/// 检测器是否就绪（自定义模型加载成功 / 内置模型可用）
- (BOOL)isReady;

@end

NS_ASSUME_NONNULL_END
