#pragma once

#import "结构.h"

int 对象类型(uint64_t Actor) {
    float MaxWalkSpeed = 读内存列<float>(Actor, {0x3D8, 0x1DC});
    if (MaxWalkSpeed == 500.0f || MaxWalkSpeed == 700.0f) {
        return 1;
    };
    uint64_t CurRow = 读内存<uint64_t>(Actor + 0x1188);
    if (CurRow) {
        return 2;
    };
    uint64_t PlayerName_Buffer = 读内存<uint64_t>(Actor + 0x24D8);
    if (PlayerName_Buffer) {
        return 3;
    };
    return 0;
};

std::string 取FString(uint64_t 地址) {
    unsigned short UTF_16[28] = {0};
    char UTF_8[448];
    读内存行(地址, UTF_16, sizeof(UTF_16));
    unsigned short* UTF_16缓冲区 = UTF_16;
    char* UTF_8缓冲区 = UTF_8;
    char *UTF_8缓冲区末尾 = UTF_8 + sizeof(UTF_8);
    while (UTF_16缓冲区 < UTF_16 + 28) {
        unsigned short 转码 = *UTF_16缓冲区;
        if (转码 <= 0x007F && UTF_8缓冲区 + 1 < UTF_8缓冲区末尾) {
            *UTF_8缓冲区++ = (char)转码;
        } else if (转码 >= 0x0080 && 转码 <= 0x07FF && UTF_8缓冲区 + 2 < UTF_8缓冲区末尾) {
            *UTF_8缓冲区++ = (char)((转码 >> 6) | 0xC0);
            *UTF_8缓冲区++ = (char)((转码 & 0x3F) | 0x80);
        } else if (转码 >= 0x0800 && 转码 <= 0xFFFF && UTF_8缓冲区 + 3 < UTF_8缓冲区末尾) {
            *UTF_8缓冲区++ = (char)((转码 >> 12) | 0xE0);
            *UTF_8缓冲区++ = (char)(((转码 >> 6) & 0x3F) | 0x80);
            *UTF_8缓冲区++ = (char)((转码 & 0x3F) | 0x80);
        } else {
            break;
        };
        UTF_16缓冲区++;
    };
    return std::string(UTF_8);
};

FMatrix 取Rotation矩阵(FRotator Rotation) {
    ImVec2 Pitch = {
        sinf(Rotation.Pitch * M_PI / 180.0f),
        cosf(Rotation.Pitch * M_PI / 180.0f),
    };
    ImVec2 Yaw = {
        sinf(Rotation.Yaw * M_PI / 180.0f),
        cosf(Rotation.Yaw * M_PI / 180.0f),
    };
    ImVec2 Roll = {
        sinf(Rotation.Roll * M_PI / 180.0f),
        cosf(Rotation.Roll * M_PI / 180.0f),
    };
    
    return {
        Pitch.y * Yaw.y,
        Pitch.y * Yaw.x,
        Pitch.x,
        0.0f,
        
        Pitch.x * Yaw.y * Roll.x - Yaw.x * Roll.y,
        Pitch.x * Yaw.x * Roll.x + Yaw.y * Roll.y,
        Pitch.y * -Roll.x,
        0.0f,
        
        -(Pitch.x * Yaw.y * Roll.y + Yaw.x * Roll.x),
        Yaw.y * Roll.x - Pitch.x * Yaw.x * Roll.y,
        Pitch.y * Roll.y,
        0.0f,
        
        0.0f,
        0.0f,
        0.0f,
        1.0f,
    };
};

FVector 取坐标差值(FVector Location, FVector WorldPosition, float 比例) {
    return {
        (WorldPosition.X - Location.X) / 比例,
        (WorldPosition.Y - Location.Y) / 比例,
        (WorldPosition.Z - Location.Z) / 比例,
    };
};

float 取距离(FVector RelativeLocation, FVector Location) {
    FVector 坐标差值 = 取坐标差值(Location, RelativeLocation, 100.0f);
    return sqrtf(powf(坐标差值.X, 2.0f) + powf(坐标差值.Y, 2.0f) + powf(坐标差值.Z, 2.0f));
};

ImVec2 取屏幕坐标(FMinimalViewInfo POV, FMatrix ViewMatrix, FVector WorldPosition, ImVec2 CAMetalDrawable) {
    FVector 坐标差值 = 取坐标差值(POV.Location, WorldPosition, 1.0f);
    FVector WorldToScreen = {
        坐标差值.X * ViewMatrix.YPlane.X + 坐标差值.Y * ViewMatrix.YPlane.Y + 坐标差值.Z * ViewMatrix.YPlane.Z,
        坐标差值.X * ViewMatrix.ZPlane.X + 坐标差值.Y * ViewMatrix.ZPlane.Y + 坐标差值.Z * ViewMatrix.ZPlane.Z,
        坐标差值.X * ViewMatrix.XPlane.X + 坐标差值.Y * ViewMatrix.XPlane.Y + 坐标差值.Z * ViewMatrix.XPlane.Z,
    };
    if (WorldToScreen.Z < 1.0f) WorldToScreen.Z = 1.0f;
    return {
        (CAMetalDrawable.x * 0.5f) + WorldToScreen.X * ((CAMetalDrawable.x * 0.5f) / tanf(POV.FOV * M_PI / 360.0f)) / WorldToScreen.Z,
        (CAMetalDrawable.y * 0.5f) - WorldToScreen.Y * ((CAMetalDrawable.x * 0.5f) / tanf(POV.FOV * M_PI / 360.0f)) / WorldToScreen.Z,
    };
};

ImU32 取等级颜色(int32_t Quality) {
    if (Quality < 1 || Quality > 6) return IM_COL32_WHITE;
    switch (Quality) {
        case 1: return IM_COL32_WHITE;
        case 2: return IM_COL32(127, 255, 127, 255);
        case 3: return IM_COL32(127, 255, 255, 255);
        case 4: return IM_COL32(255, 127, 255, 255);
        case 5: return IM_COL32(255, 255, 127, 255);
    };
    return IM_COL32(255, 127, 127, 255);;
};

std::string 截断String(std::string String) {
    size_t 开始位置 = String.find('"');
    if (开始位置 == std::string::npos) {
        return "";
    };

    size_t 结束位置 = String.find('"', 开始位置 + 1);
    if (结束位置 == std::string::npos) {
        return "";
    }

    return String.substr(开始位置 + 1, 结束位置 - 开始位置 - 1);
};

static FMatrix 取Transform矩阵(FTransform Transform) {
    return {
        1.0f - (Transform.Rotation.Y * Transform.Rotation.Y * 2.0f + Transform.Rotation.Z * Transform.Rotation.Z * 2.0f) *Transform.Scale3D.X,
        (Transform.Rotation.X * Transform.Rotation.Y * 2.0f + Transform.Rotation.W * Transform.Rotation.Z * 2.0f) * Transform.Scale3D.X,
        (Transform.Rotation.X * Transform.Rotation.Z * 2.0f - Transform.Rotation.W * Transform.Rotation.Y * 2.0f) * Transform.Scale3D.X,
        0.0f,
        
        (Transform.Rotation.X * Transform.Rotation.Y * 2.0f - Transform.Rotation.W * Transform.Rotation.Z * 2.0f) * Transform.Scale3D.Y,
        1.0f - (Transform.Rotation.X * Transform.Rotation.X * 2.0f + Transform.Rotation.Z * Transform.Rotation.Z * 2.0f) * Transform.Scale3D.Y,
        (Transform.Rotation.Y * Transform.Rotation.Z * 2.0f + Transform.Rotation.W * Transform.Rotation.X * 2.0f) * Transform.Scale3D.Y,
        0.0f,
        
        (Transform.Rotation.Y * Transform.Rotation.Z * 2.0f - Transform.Rotation.W * Transform.Rotation.X * 2.0f) * Transform.Scale3D.Z,
        1.0f - (Transform.Rotation.X * Transform.Rotation.X * 2.0f + Transform.Rotation.Y * Transform.Rotation.Y * 2.0f) * Transform.Scale3D.Z,
        0.0f,
        0.0f,
        
        Transform.Translation.X,
        Transform.Translation.Y,
        Transform.Translation.Z,
        1.0f,
    };
};

static FVector 取世界坐标(uint64_t ComponentToWorld, uint64_t StaticMesh, int ID) {
    FTransform Transform = {
        读内存<FQuat>(ComponentToWorld),
        读内存<FVector>(ComponentToWorld + 0x10),
        读内存<FVector>(ComponentToWorld + 0x1C),
    };
    FMatrix Transform矩阵 = 取Transform矩阵(Transform);
    FVector Translation = 读内存<FVector>(StaticMesh + 0x10 + ID * 0x30);
    return {
        Translation.X * Transform矩阵.XPlane.X + Translation.Y * Transform矩阵.YPlane.X + Translation.Z * Transform矩阵.ZPlane.X + Transform矩阵.WPlane.X,
        Translation.X * Transform矩阵.XPlane.Y + Translation.Y * Transform矩阵.YPlane.Y + Translation.Z * Transform矩阵.ZPlane.X + Transform矩阵.WPlane.Y,
        Translation.X * Transform矩阵.XPlane.Z + Translation.Y * Transform矩阵.YPlane.Z + Translation.Z * Transform矩阵.ZPlane.Y + Transform矩阵.WPlane.Z,
    };
};

std::vector<ImVec2> 取骨骼数组(uint64_t ComponentToWorld, uint64_t StaticMesh, FMinimalViewInfo POV, FMatrix ViewMatrix, ImVec2 CAMetalDrawable) {
    std::vector<ImVec2> 骨骼数组;
    for (int i = 0; i < 18; i++) {
        FVector 世界坐标 = 取世界坐标(ComponentToWorld, StaticMesh, 玩家骨骼点数组[i]);
        骨骼数组.push_back(取屏幕坐标(POV, ViewMatrix, 世界坐标, CAMetalDrawable));
    };
    return 骨骼数组;
};
