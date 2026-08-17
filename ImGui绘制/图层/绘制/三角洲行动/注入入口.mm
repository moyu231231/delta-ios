// ============================================================
//  注入入口 (编译为 dylib, 用 opainject 注入 DeltaForceClient)
//  注入后 dyld 加载 dylib 时自动执行 注入入口()
//  之后所有读取/自瞄都在游戏进程内完成, 零跨进程特征
// ============================================================

#import "../ImGui/imgui.h"
#import "算法.h"
#import "自瞄.h"
#import "子进程.h"
#import <UIKit/UIKit.h>
#import <pthread.h>

// 自瞄循环线程 (进程内)
static void* 自瞄循环(void*) {
    while (true) {
        uint64_t World = 读内存列<uint64_t>(DeltaForceClient, {0x15ba4f98, 0x910, 0x70});
        if (!World) { usleep(10000); continue; }
        uint64_t PlayerController = 读内存列<uint64_t>(World, {0x190, 0x38, 0x0, 0x30});
        if (!PlayerController) { usleep(10000); continue; }
        uint64_t PlayerCameraManager = 读内存<uint64_t>(PlayerController + 0x408);
        if (!PlayerCameraManager) { usleep(10000); continue; }

        FMinimalViewInfo POV;
        if (!读稳定POV(PlayerCameraManager, POV)) { usleep(10000); continue; }

        uint64_t Pawn = 读内存<uint64_t>(PlayerController + 0x3a0);
        int32_t TeamID = 读内存列<int32_t>(Pawn, {0x390, 0x658});

        ImVec2 size = {
            (float)[UIScreen mainScreen].bounds.size.width * [UIScreen mainScreen].scale,
            (float)[UIScreen mainScreen].bounds.size.height * [UIScreen mainScreen].scale,
        };

        {
            std::lock_guard<std::mutex> lock(玩家锁);
            自瞄处理(POV, PlayerCameraManager, TeamID, 玩家数据数组, size);
        }

        usleep(1000);   // 节流, 约 1000Hz 上限
    }
    return nullptr;
}

// 注入入口 (dyld 加载 dylib 时自动调用)
__attribute__((constructor))
static void 注入入口() {
    DeltaForceClient = 取主程序基址();
    if (!DeltaForceClient) return;

    pthread_t 遍历线程ID, 自瞄线程ID;
    pthread_create(&遍历线程ID, nullptr, 子进程, nullptr);
    pthread_create(&自瞄线程ID, nullptr, 自瞄循环, nullptr);
}
