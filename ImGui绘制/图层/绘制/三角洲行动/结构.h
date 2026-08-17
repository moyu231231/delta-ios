
#pragma once

#ifdef 注入模式
#import "进程内读取.h"
#else
#import "read_overwrite.h"
#endif

static uint64_t DeltaForceClient;

struct TArray {
    uint64_t AllocatorInstance;
    int ArrayNum;
    int ArrayMax;
};

struct FVector {
    float X;
    float Y;
    float Z;
};

struct FRotator {
    float Pitch;
    float Yaw;
    float Roll;
};

struct FMinimalViewInfo {
    FVector Location;
    FRotator Rotation;
    float FOV;
};

struct FPlane : FVector {
    float W;
};

struct FMatrix {
    FPlane XPlane;
    FPlane YPlane;
    FPlane ZPlane;
    FPlane WPlane;
};

struct FQuat {
    float X;
    float Y;
    float Z;
    float W;
};

struct FTransform {
    FQuat Rotation;
    FVector Translation;
    FVector Scale3D;
};

struct 玩家数据 {
    uint64_t Actor;
    uint64_t RootComponent;
    int32_t TeamID;
    uint64_t Mesh;
    uint64_t HealthSet;
    TArray StaticMesh;
    TArray EquipmentInfoArray;
    uint64_t PlayerState;
    uint64_t CacheCurWeapon;
    int64_t HeroID;
    std::string PlayerNamePrivate;
};

struct 物品数据 {
    uint64_t RootComponent;
    std::string Name;
    int32_t Quality;
    int32_t InitialGuidePrice;
};

struct 盒子数据 {
    uint64_t RootComponent;
    std::string PlayerName_Buffer;
    bool bIsAI;
};

int 玩家骨骼点数组[18] = {31, 30, 4, 3, 2, 1, 6, 7, 10, 34, 35, 38, 62, 63, 64, 58, 59, 60};
