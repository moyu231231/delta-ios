//
//  BCei
//
//  Created by Ailin 33438904 on 2025/12/3.
//

#import "HUD视图控制器.h"
#import "ImGui/imgui.h"
#import "ImGui/Metal/imgui_impl_metal.h"

#import "三角洲行动/子进程.h"
#import "三角洲行动/自瞄.h"
#include <unordered_map>

#import "../../Exploit/ExecutionKernel.h"

@implementation HUD视图控制器 {
    FBSOrientationObserver* FBSOrientationObserver;
};

- (void) viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.MTKView = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.MTKView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.MTKView.preferredFramesPerSecond = UIScreen.mainScreen.maximumFramesPerSecond;
    self.MTKView.device = MTLCreateSystemDefaultDevice();
    self.MTKView.opaque = NO;
    self.MTKView.backgroundColor = UIColor.clearColor;
    self.MTKView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.MTKView.delegate = self;
    [self.view addSubview:self.MTKView];

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsClassic();

    ImGuiIO &ImGuiIO = ImGui::GetIO();

    ImGuiIO.Fonts->Clear();
    ImFont* ImFont = ImGuiIO.Fonts->AddFontFromFileTTF([[NSBundle mainBundle] pathForResource:@"ProjectDTypeCurve-Bold" ofType:@"ttf"].UTF8String, 30.0f, nullptr, (ImWchar[]){0x20, 0x10FFFF, 0x0});
    ImFont->EllipsisChar = L' ';
    ImFont->FallbackChar = ' ';
    ImGuiIO.Fonts->Build();

    ImGui_ImplMetal_Init(self.MTKView.device);
    self.MTLCommandQueue = [self.MTKView.device newCommandQueue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSError *exploitError = nil;
        [[ExecutionKernel shared] RunWithError:&exploitError];
        if (exploitError) {
            NSLog(@"[ 三角洲行动 ] 内核初始化失败: %@", exploitError.localizedDescription);
            return;
        }

        DeltaForceClient = 取模块地址(取进程ID("DeltaForceClient"), "DeltaForceClient");
        NSLog(@"[ 三角洲行动 ] DeltaForceClient: 0x%llX", DeltaForceClient);

        pthread_t 子进程ID;
        pthread_create(&子进程ID, nullptr, 子进程, nullptr);
    });
};

- (void) drawInMTKView:(nonnull MTKView *)view {
    ImGuiIO& ImGuiIO = ImGui::GetIO();
    float width = view.bounds.size.width * UIScreen.mainScreen.scale;
    float height = view.bounds.size.height * UIScreen.mainScreen.scale;
    ImGuiIO.DisplaySize = ImVec2(width, height);
    ImGuiIO.DisplayFramebufferScale = ImVec2(1, 1);

    id<MTLCommandBuffer> MTLCommandBuffer = [self.MTLCommandQueue commandBuffer];
    MTLRenderPassDescriptor* MTLRenderPassDescriptor = view.currentRenderPassDescriptor;
    if (MTLRenderPassDescriptor == nil) {
        [MTLCommandBuffer commit];
        return;
    };
    ImGui_ImplMetal_NewFrame(MTLRenderPassDescriptor);
    ImGui::NewFrame();

    主进程(ImGui::GetBackgroundDrawList(), ImVec2(width, height));

    ImGui::Render();
    id<MTLRenderCommandEncoder> MTLRenderCommandEncoder = [MTLCommandBuffer renderCommandEncoderWithDescriptor:MTLRenderPassDescriptor];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), MTLCommandBuffer, MTLRenderCommandEncoder);
    [MTLRenderCommandEncoder endEncoding];
    [MTLCommandBuffer presentDrawable:view.currentDrawable];
    [MTLCommandBuffer commit];
};

static const char* 获取干员名称(int operatorCode) {
    static const std::unordered_map<int, const char*> operatorMap = {
        {2100654110, "红狼"},
        {2100654105, "威龙"},
        {2100654107, "蜂医"},
        {2100654109, "牧羊人"},
        {2100654108, "露娜"},
        {2100654106, "骇爪"},
        {2100654115, "乌鲁鲁"},
        {2100654116, "佐亚"},
        {2100654117, "深蓝"},
        {2100654118, "无名"},
        {2100654119, "疾风"},
    };
    auto it = operatorMap.find(operatorCode);
    return (it != operatorMap.end()) ? it->second : "?";
}

void 主进程(ImDrawList* ImDrawList, ImVec2 size) {
    uint64_t World = 读内存列<uint64_t>(DeltaForceClient, {0x15ba4f98, 0x910, 0x70});
    if (!World) return;
    uint64_t PlayerController = 读内存列<uint64_t>(World, {0x190, 0x38, 0x0, 0x30});
    if (!PlayerController) return;
    uint64_t PlayerCameraManager = 读内存<uint64_t>(PlayerController + 0x408);
    if (!PlayerCameraManager) return;

    FMinimalViewInfo POV;
    if (!读稳定POV(PlayerCameraManager, POV)) return;

    FMatrix ViewMatrix = 取Rotation矩阵(POV.Rotation);

    uint64_t Pawn = 读内存<uint64_t>(PlayerController + 0x3a0);
    int32_t TeamID = 读内存列<int32_t>(Pawn, {0x390, 0x658});

    {
        static const char* 等级名称[] = { "", "Lv1", "Lv2", "Lv3", "Lv4", "Lv5", "Lv6" };
        std::lock_guard<std::mutex> lock(物品锁);
        for (物品数据 物品 : 物品数据数组) {
            FVector RelativeLocation = 读内存<FVector>(物品.RootComponent + 0x220);
            if (RelativeLocation.X == 0.0f || RelativeLocation.Y == 0.0f || RelativeLocation.Z == 0.0f) continue;
            float 距离 = 取距离(RelativeLocation, POV.Location);
            if (距离 < 0.0f || 距离 > 50.0f) continue;
            ImVec2 屏幕坐标 = 取屏幕坐标(POV, ViewMatrix, RelativeLocation, size);
            if (屏幕坐标.x > 0.0f && 屏幕坐标.y > 0.0f && 屏幕坐标.x < size.x && 屏幕坐标.y < size.y) {
                int q = (物品.Quality >= 1 && 物品.Quality <= 6) ? 物品.Quality : 0;
                std::string 标签 = 物品.Name + " [" + 等级名称[q] + "] " + std::to_string(物品.InitialGuidePrice);
                AddText(ImDrawList, 标签, 15.0f, 屏幕坐标, 取等级颜色(物品.Quality));
            };
        };
    };

    {
        std::lock_guard<std::mutex> lock(盒子锁);
        for (盒子数据 盒子 : 盒子数据数组) {
            FVector RelativeLocation = 读内存<FVector>(盒子.RootComponent + 0x220);
            if (RelativeLocation.X == 0.0f || RelativeLocation.Y == 0.0f || RelativeLocation.Z == 0.0f) continue;
            float 距离 = 取距离(RelativeLocation, POV.Location);
            if (距离 < 0.0f || 距离 > 50.0f) continue;
            ImVec2 屏幕坐标 = 取屏幕坐标(POV, ViewMatrix, RelativeLocation, size);
            if (屏幕坐标.x > 0.0f && 屏幕坐标.y > 0.0f && 屏幕坐标.x < size.x && 屏幕坐标.y < size.y) {
                ImU32 盒子颜色 = 盒子.bIsAI ? IM_COL32(127, 255, 127, 255) : IM_COL32(255, 255, 255, 255);
                std::string 盒子标签 = 盒子.bIsAI ? "AI Box" : (截断String(盒子.PlayerName_Buffer) + " Box");
                AddText(ImDrawList, 盒子标签, 15.0f, 屏幕坐标, 盒子颜色);
            };
        };
    };

    {
        std::lock_guard<std::mutex> lock(玩家锁);
        int 玩家数量 = 0;

        for (玩家数据 玩家 : 玩家数据数组) {
            if (!玩家.Actor || 玩家.Actor == Pawn) continue;
            bool bIsDead = 读内存<bool>(玩家.Actor + 0xDD8);
            if (bIsDead) continue;
            if (玩家.TeamID == TeamID) continue;
            if (!玩家.Mesh) continue;
            if (!玩家.StaticMesh.AllocatorInstance || 玩家.StaticMesh.ArrayNum > 玩家.StaticMesh.ArrayMax) continue;

            bool bIsABot = !玩家.PlayerState;

            FVector RelativeLocation = 读内存<FVector>(玩家.RootComponent + 0x220);
            if (RelativeLocation.X == 0.0f || RelativeLocation.Y == 0.0f || RelativeLocation.Z == 0.0f) continue;
            float 距离 = 取距离(RelativeLocation, POV.Location);
            if (距离 < 0.0f || 距离 > 300.0f) continue;
            ImVec2 屏幕坐标 = 取屏幕坐标(POV, ViewMatrix, RelativeLocation, size);

            if (!bIsABot) 玩家数量++;

            if (屏幕坐标.x <= 0.0f || 屏幕坐标.y <= 0.0f || 屏幕坐标.x >= size.x || 屏幕坐标.y >= size.y) continue;
            if (!玩家.HealthSet) continue;

            float Health = 110.0f * 读内存<float>(玩家.HealthSet + 0x30 + 0xC) / 读内存<float>(玩家.HealthSet + 0x48 + 0xC);
            float ImpendingDeathHealth = 110.0f * 读内存<float>(玩家.HealthSet + 0x108 + 0xC) / 读内存<float>(玩家.HealthSet + 0x118 + 0xC);

            ImU32 骨骼颜色 = bIsABot ? IM_COL32(127, 255, 127, 255) : IM_COL32(255, 255, 127, 255);

            std::vector<ImVec2> 骨骼数组 = 取骨骼数组(玩家.Mesh + 0x210, 玩家.StaticMesh.AllocatorInstance, POV, ViewMatrix, size);

            ImDrawList->AddLine(骨骼数组[0],  骨骼数组[1],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[1],  骨骼数组[2],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[2],  骨骼数组[3],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[3],  骨骼数组[4],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[4],  骨骼数组[5],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[1],  骨骼数组[6],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[6],  骨骼数组[7],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[7],  骨骼数组[8],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[1],  骨骼数组[9],  骨骼颜色);
            ImDrawList->AddLine(骨骼数组[9],  骨骼数组[10], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[10], 骨骼数组[11], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[5],  骨骼数组[12], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[12], 骨骼数组[13], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[13], 骨骼数组[14], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[5],  骨骼数组[15], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[15], 骨骼数组[16], 骨骼颜色);
            ImDrawList->AddLine(骨骼数组[16], 骨骼数组[17], 骨骼颜色);

            AddRect(ImDrawList, ImVec4(骨骼数组[0].x - 50.0f, 骨骼数组[0].y - 11.0f, Health > 0.0f ? Health : ImpendingDeathHealth, 1.0f), IM_COL32(255, 127, 127, 255));

            AddRect(ImDrawList, ImVec4(骨骼数组[0].x - 50.0f, 骨骼数组[0].y - 31.0f, 20.0f, 20.0f), bIsABot ? IM_COL32(127, 255, 127, 255) : IM_COL32(255, 127, 127, 255));
            AddText(ImDrawList, std::to_string(玩家.TeamID), 15, ImVec2(骨骼数组[0].x - 40.0f, 骨骼数组[0].y - 21.0f), IM_COL32_WHITE, false);

            AddRect(ImDrawList, ImVec4(骨骼数组[0].x - 30.0f, 骨骼数组[0].y - 31.0f, 90.0f, 20.0f), IM_COL32(255, 255, 255, 127));
            AddText(ImDrawList, 玩家.PlayerNamePrivate, 15, ImVec2(骨骼数组[0].x + 15.0f, 骨骼数组[0].y - 21.0f), IM_COL32_WHITE);

            {
                std::string 干员 = 获取干员名称((int)玩家.HeroID);
                std::string 距离文本 = "[" + 干员 + " " + std::to_string((int)距离) + "m]";
                int32_t 头盔ID = 读内存<int32_t>(玩家.EquipmentInfoArray.AllocatorInstance + 0x30 * 1);
                int32_t 护甲ID = 读内存<int32_t>(玩家.EquipmentInfoArray.AllocatorInstance + 0x30 * 5);
                距离文本 += " H:" + std::to_string(头盔ID) + " A:" + std::to_string(护甲ID);
                AddText(ImDrawList, 距离文本,
                        15, ImVec2(骨骼数组[0].x - 50.0f, 骨骼数组[0].y - 46.0f), IM_COL32(255, 255, 127, 255), true, 1);
            };

            if (!bIsABot) ImDrawList->AddLine(ImVec2(size.x * 0.5f, 0.0f), 骨骼数组[0], IM_COL32_WHITE);
        };

        AddText(ImDrawList, std::to_string(玩家数量), 40, ImVec2(size.x * 0.5f, 100.0f), IM_COL32(255, 127, 127, 255));

        自瞄处理(POV, PlayerCameraManager, TeamID, 玩家数据数组, size);
    };
};

static void AddRect(ImDrawList* ImDrawList, ImVec4 pos, ImU32 col, float rounding = 0.0f, bool 瞄边 = false) {
    if (瞄边) {
        ImDrawList->AddRect(ImVec2(pos.x, pos.y), ImVec2(pos.x + pos.z, pos.y + pos.w), col, rounding);
    } else {
        ImDrawList->AddRectFilled(ImVec2(pos.x, pos.y), ImVec2(pos.x + pos.z, pos.y + pos.w), col, rounding);
    };
};

void AddText(ImDrawList* ImDrawList, std::string text_begin, float font_size, ImVec2 pos, ImU32 col, bool 瞄边 = true, int 方向 = 0) {
    float 缩放比例 = font_size / ImGui::GetFontSize();

    ImVec2 text_begin字体 = ImGui::CalcTextSize(text_begin.c_str());
    text_begin字体.x *= 缩放比例;
    text_begin字体.y *= 缩放比例;

    ImVec2 位置;
    switch (方向) {
        case 0: 位置 = ImVec2(pos.x - text_begin字体.x * 0.5f, pos.y - text_begin字体.y * 0.5f); break;
        case 1: 位置 = ImVec2(pos.x, pos.y - text_begin字体.y * 0.5f); break;
        case 2: 位置 = ImVec2(pos.x - text_begin字体.x, pos.y - text_begin字体.y * 0.5f); break;
        default:
            break;
    };

    if (瞄边) {
        for (int X = -1; X <= 1; X++) {
            for (int Y = -1; Y <= 1; Y++) {
                if (X == 0 && Y == 0) continue;
                ImDrawList->AddText(ImGui::GetFont(), font_size, ImVec2(位置.x + X, 位置.y + Y), IM_COL32_BLACK, text_begin.c_str());
            };
        };
    };

    ImDrawList->AddText(ImGui::GetFont(), font_size, ImVec2(位置.x, 位置.y), col, text_begin.c_str());
};

- (void) mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {

};

- (instancetype) init {
    self = [super init];
    if (self) {
        FBSOrientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak HUD视图控制器* weakSelf = self;
        [FBSOrientationObserver setHandler:^(FBSOrientationUpdate* FBSOrientationUpdate) {
            HUD视图控制器* strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf updateOrientation:(UIInterfaceOrientation)FBSOrientationUpdate.orientation animateWithDuration:FBSOrientationUpdate.duration];
            });
        }];
    };
    return self;
};

- (void) dealloc {
    [FBSOrientationObserver invalidate];
};

static inline CGFloat orientationAngle(UIInterfaceOrientation orientation) {
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        default:
            return 0;
    };
};

static inline CGRect orientationBounds(UIInterfaceOrientation orientation, CGRect bounds) {
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(0, 0, bounds.size.height, bounds.size.width);
        default:
            return bounds;
    };
};

- (void) updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration {
    CGRect Rect = orientationBounds(orientation, UIScreen.mainScreen.bounds);
    [self.view setNeedsUpdateConstraints];
    [self.view setBounds:Rect];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:duration animations:^{
        [weakSelf.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
};

@end
