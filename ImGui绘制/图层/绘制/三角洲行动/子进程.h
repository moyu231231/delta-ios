//
//  BCei
//
//  Created by Ailin 33438904 on 2025/12/3.
//
#import <mutex>
#import <unistd.h>
#import "算法.h"

static std::mutex 玩家锁;
static std::vector<玩家数据> 玩家数据数组;

static std::mutex 物品锁;
static std::vector<物品数据> 物品数据数组;

static std::mutex 盒子锁;
static std::vector<盒子数据> 盒子数据数组;

void* 子进程(void*) {
    while (true) {
        uint64_t World = 读内存列<uint64_t>(DeltaForceClient, {0x15ba4f98, 0x910, 0x70});
        if (!World) { usleep(50000); continue; }
        uint64_t PlayerController = 读内存列<uint64_t>(World, {0x190, 0x38, 0x0, 0x30});
        if (!PlayerController) { usleep(50000); continue; }
        
        TArray Actors = 读内存列<TArray>(World, {0xF8, 0x98});
        if (!Actors.AllocatorInstance || Actors.ArrayNum > Actors.ArrayMax) continue;
        
        std::vector<玩家数据> 局部_玩家数据数组;
        std::vector<物品数据> 局部_物品数据数组;
        std::vector<盒子数据> 局部_盒子数据数组;
        
        for (int i = 0; i < Actors.ArrayNum; i++) {
            uint64_t Actor = 读内存<uint64_t>(Actors.AllocatorInstance + i * 0x8);
            if (!Actor) continue;
            uint64_t RootComponent = 读内存<uint64_t>(Actor + 0x180);
            if (!RootComponent) continue;
            switch (对象类型(Actor)) {
                case 1: {
                    uint64_t Mesh = 读内存<uint64_t>(Actor + 0x3D0);
                    if (!Mesh) continue;
                    uint64_t HealthComp = 读内存<uint64_t>(Actor + 0x10C8);
                    if (!HealthComp) continue;
                    TArray StaticMesh = 读内存<TArray>(Mesh + 0x730);
                    if (!StaticMesh.AllocatorInstance || StaticMesh.ArrayNum > StaticMesh.ArrayMax) StaticMesh = 读内存<TArray>(Mesh + 0x730);
                    
                    uint64_t PlayerState = 读内存<uint64_t>(Actor + 0x390);
                    int32_t TeamID = 读内存<int32_t>(PlayerState + 0x658);
                    
                    玩家数据 玩家;
                    玩家.Actor = Actor;
                    玩家.RootComponent = RootComponent;
                    玩家.TeamID = TeamID;
                    玩家.Mesh = Mesh;
                    玩家.StaticMesh = StaticMesh;
                    玩家.HealthSet = 读内存<uint64_t>(HealthComp + 0x280);
                    玩家.EquipmentInfoArray = 读内存列<TArray>(Actor, {0x37D8, 0x1D8});
                    玩家.PlayerState = PlayerState;
                    玩家.CacheCurWeapon = 读内存<uint64_t>(Actor + 0x1790);
                    玩家.HeroID = 读内存<int64_t>(PlayerState + 0x9E8);
                    玩家.PlayerNamePrivate = !PlayerState ? "人机" : 取FString(读内存<uint64_t>(PlayerState + 0x470));
                    局部_玩家数据数组.push_back(玩家);
                    break;
                };
                case 2: {
                    uint64_t CurRow = 读内存<uint64_t>(Actor + 0x11B0);
                    if (!CurRow) continue;
                    int32_t InitialGuidePrice = 读内存<int32_t>(CurRow + 0xDC);
                    if (InitialGuidePrice > 0) {
                        物品数据 物品;
                        物品.RootComponent = RootComponent;
                        物品.Name = 取FString(读内存列<uint64_t>(CurRow, {0x18, 0x18, 0x20, 0x10}));
                        物品.Quality = 读内存<int32_t>(CurRow + 0x68);
                        物品.InitialGuidePrice = 读内存<int32_t>(CurRow + 0xDC);
                        局部_物品数据数组.push_back(物品);
                    };
                    break;
                };
                case 3: {
                    盒子数据 盒子;
                    盒子.RootComponent = RootComponent;
                    盒子.PlayerName_Buffer = 取FString(读内存<uint64_t>(Actor + 0x24D8));
                    盒子.bIsAI = 读内存<bool>(Actor + 0x2568);
                    局部_盒子数据数组.push_back(盒子);
                    break;
                };
            };
        };
        
        {
            std::lock_guard<std::mutex> lock(玩家锁);
            玩家数据数组.swap(局部_玩家数据数组);
        };
        {
            std::lock_guard<std::mutex> lock(物品锁);
            物品数据数组.swap(局部_物品数据数组);
        };
        {
            std::lock_guard<std::mutex> lock(盒子锁);
            盒子数据数组.swap(局部_盒子数据数组);
        };

        usleep(2000);   // 节流：限制遍历频率，避免疯狂轮询（也降低读取抖动）
    };
};
