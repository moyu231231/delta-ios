// 悬浮球.mm —— 极简悬浮开关实现
// 一个可拖动的圆点：点击 = 开/关自瞄，长按 = 退出 App
#import "悬浮球.h"
#import "自瞄引擎.h"

@interface FloatingBall ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *ball;
@end

@implementation FloatingBall

+ (void)show {
    static FloatingBall *ball = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ball = [[FloatingBall alloc] init];
    });
    [ball _setup];
}

- (void)_setup {
    CGRect screen = [UIScreen mainScreen].bounds;
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(screen.size.width - 80, 200, 60, 60)];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = [UIColor clearColor];

    self.ball = [UIButton buttonWithType:UIButtonTypeCustom];
    self.ball.frame = self.window.bounds;
    self.ball.layer.cornerRadius = 30;
    self.ball.backgroundColor = [UIColor colorWithRed:0 green:0.8 blue:1 alpha:0.7];
    self.ball.layer.borderColor = [UIColor whiteColor].CGColor;
    self.ball.layer.borderWidth = 2;
    self.ball.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.ball setTitle:@"自瞄" forState:UIControlStateNormal];
    [self.ball setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    // 拖动
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_onPan:)];
    [self.ball addGestureRecognizer:pan];

    // 点击开关
    [self.ball addTarget:self action:@selector(_onTap) forControlEvents:UIControlEventTouchUpInside];

    // 长按退出
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_onLongPress)];
    lp.minimumPressDuration = 1.5;
    [self.ball addGestureRecognizer:lp];

    [self.window addSubview:self.ball];
    self.window.hidden = NO;
}

- (void)_onPan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    CGPoint translation = [pan translationInView:view.superview];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    view.center = center;
    [pan setTranslation:CGPointZero inView:view.superview];
}

- (void)_onTap {
    AimbotEngine *e = [AimbotEngine shared];
    e.enabled = !e.enabled;
    [self.ball setTitle:e.enabled ? @"自瞄✓" : @"自瞄✗" forState:UIControlStateNormal];
    self.ball.backgroundColor = e.enabled ?
        [UIColor colorWithRed:0 green:0.8 blue:0.4 alpha:0.8] :
        [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.7];
}

- (void)_onLongPress {
    exit(0);
}

+ (void)hide {
    // 无操作，悬浮球常驻
}

@end
