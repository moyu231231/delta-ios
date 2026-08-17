// 目标识别.mm —— Vision/CoreML 目标检测实现
//
// 内置方案用 VNRecognizeObjectsRequest（iOS 12+，苹果内置目标检测模型），
// 自定义方案用 VNCoreMLRequest（加载用户提供的 YOLO .mlmodel）。
//
// ⚠️ 精度说明：内置模型识别「人」是通用行人检测，对游戏角色（卡通/迷彩/小目标）
//    精度有限。要打三角洲，强烈建议用你 PC 端 YOLOv14 的模型转 CoreML
//    （.mlmodel），识别你的目标敌人。

#import "目标识别.h"
#import <Vision/Vision.h>
#import <CoreML/CoreML.h>

@implementation Target
@end

@interface TargetDetector ()
@property (nonatomic, assign) BOOL useBuiltIn;
@property (nonatomic, copy)   NSString *modelName;
@property (nonatomic, strong) VNCoreMLModel *coreMLModel;
@property (nonatomic, strong) VNCoreMLRequest *coreMLRequest;
@property (nonatomic, strong) VNRecognizeObjectsRequest *builtInRequest;
@end

@implementation TargetDetector

+ (instancetype)builtInDetector {
    TargetDetector *d = [[TargetDetector alloc] init];
    d.useBuiltIn = YES;
    return d;
}

+ (instancetype)detectorWithCoreMLModel:(NSString *)mlmodelName {
    TargetDetector *d = [[TargetDetector alloc] init];
    d.useBuiltIn = NO;
    d.modelName = mlmodelName;

    // 加载 CoreML 模型（支持 .mlmodelc / .mlpackage / .mlmodel 三种格式）
    NSURL *url = [[NSBundle mainBundle] URLForResource:mlmodelName withExtension:@"mlmodelc"];
    if (!url) url = [[NSBundle mainBundle] URLForResource:mlmodelName withExtension:@"mlpackage"];
    if (!url) url = [[NSBundle mainBundle] URLForResource:mlmodelName withExtension:@"mlmodel"];
    if (url) {
        NSError *err = nil;
        MLModel *ml = [MLModel modelWithContentsOfURL:url configuration:nil error:&err];
        if (ml) {
            d.coreMLModel = [VNCoreMLModel modelForMLModel:ml error:&err];
        }
    }
    return d;
}

- (VNRecognizeObjectsRequest *)builtInRequest {
    if (!_builtInRequest) {
        _builtInRequest = [[VNRecognizeObjectsRequest alloc] init];
        _builtInRequest.usesCPUOnly = NO;   // 用 NPU 加速
    }
    return _builtInRequest;
}

- (NSArray<Target *> *)detectInImage:(UIImage *)image {
    if (!image) return @[];

    // UIImage → CGImage
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return @[];

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];

    NSMutableArray<Target *> *results = [NSMutableArray array];

    if (self.useBuiltIn) {
        // 内置 Vision 方案
        NSError *err = nil;
        [handler performRequests:@[self.builtInRequest] error:&err];
        if (err) return @[];

        for (VNRecognizedObjectObservation *obs in self.builtInRequest.results) {
            Target *t = [[Target alloc] init];
            t.boundingBox = obs.boundingBox;
            VNClassificationObservation *top = obs.labels.firstObject;
            t.label = top.identifier ?: @"object";
            t.confidence = top.confidence;
            t.isHead = [t.label.lowercaseString containsString:@"head"];
            [results addObject:t];
        }
    } else if (self.coreMLModel) {
        // 自定义 CoreML 方案
        if (!self.coreMLRequest) {
            self.coreMLRequest = [[VNCoreMLRequest alloc] initWithModel:self.coreMLModel];
            self.coreMLRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;
        }
        NSError *err = nil;
        [handler performRequests:@[self.coreMLRequest] error:&err];
        if (err) return @[];

        for (id result in self.coreMLRequest.results) {
            if ([result isKindOfClass:[VNRecognizedObjectObservation class]]) {
                VNRecognizedObjectObservation *obs = (VNRecognizedObjectObservation *)result;
                Target *t = [[Target alloc] init];
                t.boundingBox = obs.boundingBox;
                VNClassificationObservation *top = obs.labels.firstObject;
                t.label = top.identifier ?: @"enemy";
                t.confidence = top.confidence;
                t.isHead = [t.label.lowercaseString containsString:@"head"];
                [results addObject:t];
            }
        }
    }

    return results;
}

- (NSArray<Target *> *)detectPersonsInImage:(UIImage *)image {
    NSArray<Target *> *all = [self detectInImage:image];
    NSMutableArray<Target *> *persons = [NSMutableArray array];
    for (Target *t in all) {
        NSString *lbl = t.label.lowercaseString;
        if ([lbl containsString:@"person"] || [lbl containsString:@"human"] ||
            [lbl containsString:@"man"]   || [lbl containsString:@"enemy"] ||
            [lbl containsString:@"player"] || [lbl containsString:@"人"] ||
            [lbl containsString:@"head"]   || [lbl containsString:@"body"] ||
            [lbl containsString:@"头"]     || [lbl containsString:@"身"]) {
            [persons addObject:t];
        }
    }
    // 兜底：若没有识别出「人」类标签，返回全部（让用户看到识别效果）
    if (persons.count == 0) return all;
    return persons;
}

- (BOOL)isReady {
    if (self.useBuiltIn) return YES;       // 内置 Vision 恒可用
    return (self.coreMLModel != nil);      // 自定义模型：加载成功才就绪
}

@end
