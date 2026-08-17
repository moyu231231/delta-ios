// 触摸注入.mm —— 跨进程 IOHIDEvent 触摸注入实现
// 使用 IOKit 私有 API 动态加载（不链接私有 framework，编译无需私有 .tbd）
//
// ⚠️ 签名说明：以下 IOHIDEvent 函数签名基于 iOS 15/16 公开私有头文件，
//    不同 iOS 版本可能有细微差异，真机实测时如注入无反应，优先校准
//    IOHIDEventCreateDigitizerFingerEvent 的参数顺序与 eventMask 常量。

#import "触摸注入.h"
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <UIKit/UIKit.h>
#include <unistd.h>

// ============================================================
// IOHIDEvent 私有类型与常量（与 IOKit 私有头文件一致）
// ============================================================

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef uint32_t IOHIDEventField;
typedef double IOHIDFloat;

// Digitizer 事件掩码
#define kIOHIDDigitizerEventRange      0x00000001
#define kIOHIDDigitizerEventTouch      0x00000002
#define kIOHIDDigitizerEventPosition   0x00000004
#define kIOHIDDigitizerEventIdentity   0x00000008
#define kIOHIDDigitizerEventAttribute  0x00000010

// Digitizer 字段索引（IOHIDEventField）
#define kIOHIDEventFieldDigitizerX     0x00060000
#define kIOHIDEventFieldDigitizerY     0x00060001
#define kIOHIDEventFieldDigitizerZ     0x00060002

// 函数指针类型
typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate_t)(CFAllocatorRef);
typedef IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEvent_t)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t,
    IOHIDFloat, IOHIDFloat, IOHIDFloat,
    IOHIDFloat, IOHIDFloat, Boolean, Boolean, Boolean);
typedef void (*IOHIDEventSetFloatValue_t)(IOHIDEventRef, IOHIDEventField, IOHIDFloat);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(IOHIDEventSystemClientRef, IOHIDEventRef);

static IOHIDEventSystemClientCreate_t              _HIDClientCreate = NULL;
static IOHIDEventCreateDigitizerFingerEvent_t      _HIDCreateFinger = NULL;
static IOHIDEventSetFloatValue_t                   _HIDSetFloat = NULL;
static IOHIDEventSystemClientDispatchEvent_t       _HIDDispatch = NULL;
static IOHIDEventSystemClientRef                   _client = NULL;

// 当前触摸状态
static BOOL        _isTouching = NO;
static CGPoint     _lastPoint = CGPointZero;

// ============================================================
// 动态加载 IOHIDEvent 私有 API
// ============================================================
+ (BOOL)setup {
    static dispatch_once_t onceToken;
    static BOOL ok = NO;
    dispatch_once(&onceToken, ^{
        void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!iokit) {
            iokit = dlopen("/System/Library/PrivateFrameworks/IOKit.framework/IOKit", RTLD_LAZY);
        }
        if (!iokit) return;

        _HIDClientCreate = (IOHIDEventSystemClientCreate_t)dlsym(iokit, "IOHIDEventSystemClientCreate");
        _HIDCreateFinger = (IOHIDEventCreateDigitizerFingerEvent_t)dlsym(iokit, "IOHIDEventCreateDigitizerFingerEvent");
        _HIDSetFloat = (IOHIDEventSetFloatValue_t)dlsym(iokit, "IOHIDEventSetFloatValue");
        _HIDDispatch = (IOHIDEventSystemClientDispatchEvent_t)dlsym(iokit, "IOHIDEventSystemClientDispatchEvent");

        if (_HIDClientCreate && _HIDCreateFinger && _HIDDispatch) {
            _client = _HIDClientCreate(kCFAllocatorDefault);
            ok = (_client != NULL);
        }
    });
    return ok;
}

// ============================================================
// 内部：构造并派发一个 digitizer 手指事件
// ============================================================
static void _dispatchTouch(CGPoint point, BOOL touch, BOOL range) {
    if (!_client || !_HIDCreateFinger || !_HIDDispatch) return;

    // 屏幕坐标 → 逻辑坐标（iOS 触摸注入使用逻辑点）
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat x = point.x;
    CGFloat y = point.y;
    (void)scale;

    uint64_t now = mach_absolute_time();
    uint32_t eventMask = kIOHIDDigitizerEventTouch |
                         kIOHIDDigitizerEventPosition |
                         kIOHIDDigitizerEventIdentity;
    if (range) eventMask |= kIOHIDDigitizerEventRange;

    // 创建手指事件
    // 参数: allocator, 时间戳, 手指索引, 身份, 事件掩码,
    //       x, y, z, tipPressure, barrelPressure, range, touch, options
    IOHIDEventRef event = _HIDCreateFinger(
        kCFAllocatorDefault, now,
        0,              // 手指索引（单指 = 0）
        2,              // 身份（任意非零稳定值）
        eventMask,
        x, y, 0.0,      // 坐标
        1.0, 0.0,       // 压力
        range, touch, 0 // range/touch/options
    );

    if (!event) return;

    // 显式设置坐标（部分版本需单独 set，双保险）
    if (_HIDSetFloat) {
        _HIDSetFloat(event, kIOHIDEventFieldDigitizerX, x);
        _HIDSetFloat(event, kIOHIDEventFieldDigitizerY, y);
    }

    _HIDDispatch(_client, event);
    CFRelease(event);
}

// ============================================================
// 触摸操作
// ============================================================
+ (void)touchDownAt:(CGPoint)point {
    if (![self setup]) return;
    _isTouching = YES;
    _lastPoint = point;
    _dispatchTouch(point, YES, YES);   // touch=1, range=1（手指按下进入）
}

+ (void)touchMoveTo:(CGPoint)point {
    if (!_isTouching) { [self touchDownAt:point]; return; }
    _lastPoint = point;
    _dispatchTouch(point, YES, NO);    // touch=1, range=0（手指在屏内移动）
}

+ (void)touchUpAt:(CGPoint)point {
    if (!_isTouching) return;
    _isTouching = NO;
    _dispatchTouch(point, NO, NO);     // touch=0, range=0（手指抬起）
}

+ (void)tapAt:(CGPoint)point {
    [self touchDownAt:point];
    // 短按 40ms（模拟真实点击速度）
    usleep(40000);
    [self touchUpAt:point];
}

+ (void)dragFrom:(CGPoint)from to:(CGPoint)to duration:(NSTimeInterval)duration {
    if (duration <= 0) duration = 0.05;
    [self touchDownAt:from];

    int steps = (int)(duration * 240);  // 240Hz 采样，足够平滑
    if (steps < 2) steps = 2;
    if (steps > 60) steps = 60;          // 上限 60 步，避免卡顿

    for (int i = 1; i <= steps; i++) {
        CGFloat t = (CGFloat)i / (CGFloat)steps;
        // 缓动曲线（先快后慢，模拟真人甩枪）
        CGFloat ease = 1.0 - pow(1.0 - t, 1.5);
        CGPoint p = CGPointMake(
            from.x + (to.x - from.x) * ease,
            from.y + (to.y - from.y) * ease
        );
        [self touchMoveTo:p];
        usleep((useconds_t)(duration * 1000000 / steps));
    }
    [self touchUpAt:to];
}

@end
