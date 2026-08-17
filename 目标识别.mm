// 目标识别.mm —— CoreML 目标检测实现（三角洲 head/body 模型）
//
// 用 VNCoreMLRequest 加载 best.mlmodelc（三角洲公益模型转的 CoreML），
// 模型输出 cls0=body（身体）、cls1=head（头部）两个类别，头身分离锁头准。
#import "目标识别.h"
#import <Vision/Vision.h>
#import <CoreML/CoreML.h>

@implementation Target
@end

@implementation TargetDetector {
    VNCoreMLModel *_coreMLModel;
    VNCoreMLRequest *_coreMLRequest;
}

+ (instancetype)detectorWithCoreMLModel:(NSString *)mlmodelName {
    TargetDetector *d = [[TargetDetector alloc] init];

    // 加载 CoreML 模型（支持 .mlmodelc / .mlpackage / .mlmodel 三种格式）
    NSURL *url = [[NSBundle mainBundle] URLForResource:mlmodelName withExtension:@"mlmodelc"];
    if (!url) url = [[NSBundle mainBundle] URLForResource:mlmodelName withExtension:@"mlpackage"];
    if (!url) url = [[NSBundle mainBundle] URLForResource:mlmodelName withExtension:@"mlmodel"];
    if (url) {
        NSError *err = nil;
        MLModelConfiguration *cfg = [[MLModelConfiguration alloc] init];
        MLModel *ml = [MLModel modelWithContentsOfURL:url configuration:cfg error:&err];
        if (ml) {
            d->_coreMLModel = [VNCoreMLModel modelForMLModel:ml error:&err];
        }
    }
    return d;
}

- (NSArray<Target *> *)detectInImage:(UIImage *)image {
    if (!image || !_coreMLModel) return @[];

    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return @[];

    if (!_coreMLRequest) {
        _coreMLRequest = [[VNCoreMLRequest alloc] initWithModel:_coreMLModel];
        _coreMLRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;
    }

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    NSError *err = nil;
    [handler performRequests:@[_coreMLRequest] error:&err];
    if (err) return @[];

    NSMutableArray<Target *> *results = [NSMutableArray array];
    for (id result in _coreMLRequest.results) {
        if ([result isKindOfClass:[VNRecognizedObjectObservation class]]) {
            VNRecognizedObjectObservation *obs = (VNRecognizedObjectObservation *)result;
            Target *t = [[Target alloc] init];
            t.boundingBox = obs.boundingBox;
            VNClassificationObservation *top = obs.labels.firstObject;
            t.label = top.identifier ?: @"object";
            t.confidence = top.confidence;
            t.isHead = [t.label.lowercaseString containsString:@"head"];
            [results addObject:t];
        }
    }
    return results;
}

- (BOOL)isReady {
    return (_coreMLModel != nil);
}

@end
