//
//  BCei
//
//  Created by Ailin 33438904 on 2025/12/3.
//
#import <MetalKit/MTKView.h>

@interface FBSOrientationObserver : NSObject
- (long long)activeInterfaceOrientation;
- (void)activeInterfaceOrientationWithCompletion:(id)ID;
- (void)invalidate;
- (void)setHandler:(id)ID;
- (id)handler;
@end

@interface FBSOrientationUpdate : NSObject
- (unsigned long long)sequenceNumber;
- (long long)rotationDirection;
- (long long)orientation;
- (double)duration;
@end

@interface HUD视图控制器 : UIViewController <MTKViewDelegate>
@property (nonatomic, strong) MTKView* MTKView;
@property (nonatomic, strong) id <MTLCommandQueue> MTLCommandQueue;
@end
