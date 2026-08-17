#pragma once

#import "算法.h"
#include <cmath>
#include <cstring>
#include <stdlib.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ============================================================
//  自瞄模块 (aimbot)
//  FOV筛选 + 准星夹角最小优先 + 平滑过渡 + 目标锁定
// ============================================================

struct 自瞄配置 {
    bool 开启 = true;              // 自瞄总开关（每帧由 HUD 从 UserDefaults 读）
    bool 锁头 = true;              // true=锁头(骨骼31) false=锁胸(骨骼30)
    float FOV半径 = 200.0f;        // 准星圈半径 (屏幕像素)，圈到人就瞄
    float 平滑度 = 0.15f;          // 0~1 越小越平滑（越像真人）
    float 最大距离 = 300.0f;       // 米
    bool 人体工学抖动 = false;     // 默认关
    float 抖动幅度 = 0.25f;        // 度
    uint64_t 锁定Actor = 0;        // 跨帧锁定目标
};
static 自瞄配置 自瞄;

static FMinimalViewInfo 上一帧POV = {};
static bool 有上一帧POV = false;

// ============ 值域校验 ============
static bool 是合法向量(FVector 向量) {
    if (isnan(向量.X) || isnan(向量.Y) || isnan(向量.Z)) return false;
    if (isinf(向量.X) || isinf(向量.Y) || isinf(向量.Z)) return false;
    if (fabsf(向量.X) > 1e7f || fabsf(向量.Y) > 1e7f || fabsf(向量.Z) > 1e7f) return false;
    return true;
}

static bool 是合法旋转(FRotator 旋转) {
    if (isnan(旋转.Pitch) || isnan(旋转.Yaw) || isnan(旋转.Roll)) return false;
    if (fabsf(旋转.Pitch) > 90.0f) return false;
    if (fabsf(旋转.Yaw) > 360.0f) return false;
    return true;
}

static bool 是合法POV(FMinimalViewInfo POV) {
    if (!是合法向量(POV.Location) || !是合法旋转(POV.Rotation)) return false;
    if (isnan(POV.FOV) || POV.FOV <= 0.0f || POV.FOV > 180.0f) return false;
    if (POV.Location.X == 0.0f && POV.Location.Y == 0.0f && POV.Location.Z == 0.0f) return false;
    return true;
}

// ============ 读 POV ============
// ViewTarget = PlayerCameraManager + 0x17A0, POV = ViewTarget + 0x10
static FMinimalViewInfo 读原始POV(uint64_t PlayerCameraManager) {
    return {
        读内存<FVector>(PlayerCameraManager + 0x17A0 + 0x10),
        读内存<FRotator>(PlayerCameraManager + 0x17A0 + 0x10 + 0x10),
        读内存<float>(PlayerCameraManager + 0x17A0 + 0x10 + 0x1C),
    };
}

static bool 读稳定POV(uint64_t PlayerCameraManager, FMinimalViewInfo &POV) {
    FMinimalViewInfo A = 读原始POV(PlayerCameraManager);
    FMinimalViewInfo B = 读原始POV(PlayerCameraManager);
    bool 两次一致 = (memcmp(&A, &B, sizeof(FMinimalViewInfo)) == 0);
    bool A合法 = 是合法POV(A);

    if (两次一致 && A合法) {
        if (有上一帧POV) {
            // 一阶低通滤波：滤掉单帧角度尖峰（读取稳定，自瞄不抖）
            const float 滤波系数 = 0.7f;  // 越小越平滑，但延迟越大
            FMinimalViewInfo 滤波后 = A;
            float Yaw差 = A.Rotation.Yaw - 上一帧POV.Rotation.Yaw;
            while (Yaw差 > 180.0f) Yaw差 -= 360.0f;
            while (Yaw差 < -180.0f) Yaw差 += 360.0f;
            滤波后.Rotation.Yaw = 上一帧POV.Rotation.Yaw + Yaw差 * 滤波系数;
            滤波后.Rotation.Pitch = 上一帧POV.Rotation.Pitch + (A.Rotation.Pitch - 上一帧POV.Rotation.Pitch) * 滤波系数;
            滤波后.Rotation.Roll = 0.0f;
            POV = 滤波后;
        } else {
            POV = A;
        }
        上一帧POV = A;  // 缓存原始值（下一帧滤波用它）
        有上一帧POV = true;
        return true;
    }
    if (有上一帧POV) {
        POV = 上一帧POV;
        return true;
    }
    return false;
}

// ============ 角度计算 ============
static FRotator 取目标角度(FVector 相机位置, FVector 目标位置) {
    FVector 差 = {
        目标位置.X - 相机位置.X,
        目标位置.Y - 相机位置.Y,
        目标位置.Z - 相机位置.Z,
    };
    float 水平距离 = sqrtf(差.X * 差.X + 差.Y * 差.Y);
    if (水平距离 < 0.001f) return {0.0f, 0.0f, 0.0f};
    float Pitch = atan2f(差.Z, 水平距离) * 180.0f / (float)M_PI;
    float Yaw = atan2f(差.Y, 差.X) * 180.0f / (float)M_PI;
    return {Pitch, Yaw, 0.0f};
}

// ============ 平滑 ============
static FRotator 平滑角度(FRotator 当前, FRotator 目标, float 平滑度, bool 抖动, float 抖动幅度) {
    if (平滑度 < 0.01f) 平滑度 = 0.01f;
    if (平滑度 > 1.0f) 平滑度 = 1.0f;
    FRotator 结果 = 当前;
    float Yaw差 = 目标.Yaw - 当前.Yaw;
    while (Yaw差 > 180.0f) Yaw差 -= 360.0f;
    while (Yaw差 < -180.0f) Yaw差 += 360.0f;
    结果.Yaw = 当前.Yaw + Yaw差 * 平滑度;
    结果.Pitch = 当前.Pitch + (目标.Pitch - 当前.Pitch) * 平滑度;
    结果.Roll = 0.0f;
    if (抖动) {
        auto 噪声 = [](float 幅度) {
            return ((float)arc4random_uniform(10000) / 10000.0f - 0.5f) * 2.0f * 幅度;
        };
        结果.Yaw += 噪声(抖动幅度);
        结果.Pitch += 噪声(抖动幅度);
    }
    return 结果;
}

// ============ 选目标 ============
static uint64_t 选自瞄目标(const std::vector<玩家数据> &玩家数组, FMinimalViewInfo POV,
                           FMatrix ViewMatrix, ImVec2 size, int32_t 本方队伍, uint64_t 当前锁定) {
    uint64_t 最佳Actor = 0;
    float 最佳屏幕距离 = 自瞄.FOV半径;

    for (const 玩家数据 &玩家 : 玩家数组) {
        if (!玩家.Actor) continue;
        if (玩家.TeamID == 本方队伍) continue;
        if (!玩家.Mesh || !玩家.StaticMesh.AllocatorInstance) continue;
        if (读内存<bool>(玩家.Actor + 0xDD8)) continue;
        FVector RelativeLocation = 读内存<FVector>(玩家.RootComponent + 0x220);
        if (!是合法向量(RelativeLocation)) continue;
        if (RelativeLocation.X == 0.0f && RelativeLocation.Y == 0.0f && RelativeLocation.Z == 0.0f) continue;
        float 距离 = 取距离(RelativeLocation, POV.Location);
        if (距离 < 0.0f || 距离 > 自瞄.最大距离) continue;
        ImVec2 屏幕坐标 = 取屏幕坐标(POV, ViewMatrix, RelativeLocation, size);
        if (屏幕坐标.x <= 0.0f || 屏幕坐标.y <= 0.0f || 屏幕坐标.x >= size.x || 屏幕坐标.y >= size.y) continue;
        float 屏幕距离 = sqrtf(powf(屏幕坐标.x - size.x * 0.5f, 2.0f) + powf(屏幕坐标.y - size.y * 0.5f, 2.0f));
        if (玩家.Actor == 当前锁定 && 屏幕距离 < 自瞄.FOV半径 * 1.5f) {
            return 当前锁定;
        }
        if (屏幕距离 < 最佳屏幕距离) {
            最佳屏幕距离 = 屏幕距离;
            最佳Actor = 玩家.Actor;
        }
    }
    return 最佳Actor;
}

// ============ 自瞄主处理 ============
static void 自瞄处理(FMinimalViewInfo POV, uint64_t PlayerCameraManager, int32_t 本方队伍,
                     const std::vector<玩家数据> &玩家数组, ImVec2 size) {
    if (!自瞄.开启) { 自瞄.锁定Actor = 0; return; }
    if (!有上一帧POV) return;

    FMatrix ViewMatrix = 取Rotation矩阵(POV.Rotation);

    uint64_t 目标 = 选自瞄目标(玩家数组, POV, ViewMatrix, size, 本方队伍, 自瞄.锁定Actor);
    if (!目标) { 自瞄.锁定Actor = 0; return; }
    自瞄.锁定Actor = 目标;

    const 玩家数据 *目标玩家 = nullptr;
    for (const 玩家数据 &玩家 : 玩家数组) {
        if (玩家.Actor == 目标) { 目标玩家 = &玩家; break; }
    }
    if (!目标玩家) return;

    int 骨骼点 = 自瞄.锁头 ? 玩家骨骼点数组[0] : 玩家骨骼点数组[1];
    FVector 目标骨骼 = 取世界坐标(目标玩家->Mesh + 0x210, 目标玩家->StaticMesh.AllocatorInstance, 骨骼点);
    if (!是合法向量(目标骨骼)) return;

    FRotator 目标角度 = 取目标角度(POV.Location, 目标骨骼);
    FRotator 写入角度 = 平滑角度(POV.Rotation, 目标角度, 自瞄.平滑度, 自瞄.人体工学抖动, 自瞄.抖动幅度);

    // 写视角角度（写 ViewTarget.POV.Rotation）
    写内存<FRotator>(PlayerCameraManager + 0x17A0 + 0x10 + 0x10, 写入角度);
}
