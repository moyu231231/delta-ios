#import "kfd.h"
#import "通用类型.h"

#import <Foundation/NSString.h>

UE4::FMinimalViewInfo 取POV(uint64_t POV) {
    return {
        kfd.取物理<UE4::FVector>(POV + 0x0),
        kfd.取物理<UE4::FRotator>(POV + 0x18),
        kfd.取物理<float>(POV + 0x24),
    };
};

UE4::FMatrix 取矩阵(UE4::FRotator Rotation) {
    UE4::FVector2D Pitch = {
        sinf(Rotation.Pitch * M_PI / 180.0f),
        cosf(Rotation.Pitch * M_PI / 180.0f),
    };
    UE4::FVector2D Yaw = {
        sinf(Rotation.Yaw * M_PI / 180.0f),
        cosf(Rotation.Yaw * M_PI / 180.0f),
    };
    UE4::FVector2D Roll = {
        sinf(Rotation.Roll * M_PI / 180.0f),
        cosf(Rotation.Roll * M_PI / 180.0f),
    };
    
    return {
        Pitch.Y * Yaw.Y,
        Pitch.Y * Yaw.X,
        Pitch.X,
        0.0f,
        
        Pitch.X * Yaw.Y * Roll.X - Yaw.X * Roll.Y,
        Pitch.X * Yaw.X * Roll.X + Yaw.Y * Roll.Y,
        Pitch.Y * -Roll.X,
        0.0f,
        
        - (Pitch.X * Yaw.Y * Roll.Y + Yaw.X * Roll.X),
        Yaw.Y * Roll.X - Pitch.X * Yaw.X * Roll.Y,
        Pitch.Y * Roll.Y,
        0.0f,
        
        0.0f,
        0.0f,
        0.0f,
        1.0f,
    };
};

UE4::FVector 取世界坐标差(UE4::FVector 世界坐标, UE4::FVector Location, float 比例) {
    return {
        (世界坐标.X - Location.X) / 比例,
        (世界坐标.Y - Location.Y) / 比例,
        (世界坐标.Z - Location.Z) / 比例,
    };
};

float 取世界距离(UE4::FVector RelativeLocation, UE4::FVector Location) {
    UE4::FVector 世界坐标差 = 取世界坐标差(RelativeLocation, Location, 100.0f);
    return sqrtf(powf(世界坐标差.X, 2.0f) + powf(世界坐标差.Y, 2.0f) + powf(世界坐标差.Z, 2.0f));
};

UE4::FTransform 取Transform(uint64_t ComponentToWorld) {
    return {
        kfd.取物理<UE4::FQuat>(ComponentToWorld + 0x0),
        kfd.取物理<UE4::FVector>(ComponentToWorld + 0x10),
        kfd.取物理<UE4::FVector>(ComponentToWorld + 0x20),
    };
};

UE4::FMatrix 取Transform矩阵(UE4::FTransform Transform) {
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

UE4::FVector 取骨骼世界坐标(uint64_t ComponentToWorld, uint64_t StaticMesh, int 骨骼点) {
    UE4::FTransform Transform = 取Transform(ComponentToWorld);
    UE4::FMatrix Transform矩阵 = 取Transform矩阵(Transform);
    UE4::FVector Translation = kfd.取物理<UE4::FVector>(StaticMesh + 0x10 + 骨骼点 * 0x30);
    return {
        Translation.X * Transform矩阵.XPlane.X + Translation.Y * Transform矩阵.YPlane.X + Translation.Z * Transform矩阵.ZPlane.X + Transform矩阵.WPlane.X,
        Translation.X * Transform矩阵.XPlane.Y + Translation.Y * Transform矩阵.YPlane.Y + Translation.Z * Transform矩阵.ZPlane.X + Transform矩阵.WPlane.Y,
        Translation.X * Transform矩阵.XPlane.Z + Translation.Y * Transform矩阵.YPlane.Z + Translation.Z * Transform矩阵.ZPlane.Y + Transform矩阵.WPlane.Z,
    };
};

void 取屏幕坐标(UE4::FVector 世界坐标, UE4::FMinimalViewInfo POV, UE4::FMatrix 矩阵, UE4::FVector2D 屏幕坐标, ImVec2 &坐标) {
    UE4::FVector 世界坐标差 = 取世界坐标差(世界坐标, POV.Location, 1.0f);
    UE4::FVector 世界x矩阵 = {
        世界坐标差.X * 矩阵.YPlane.X + 世界坐标差.Y * 矩阵.YPlane.Y + 世界坐标差.Z * 矩阵.YPlane.Z,
        世界坐标差.X * 矩阵.ZPlane.X + 世界坐标差.Y * 矩阵.ZPlane.Y + 世界坐标差.Z * 矩阵.ZPlane.Z,
        世界坐标差.X * 矩阵.XPlane.X + 世界坐标差.Y * 矩阵.XPlane.Y + 世界坐标差.Z * 矩阵.XPlane.Z,
    };
    if (世界x矩阵.Z < 1.0f) 世界x矩阵.Z = 1.0f;
    坐标 = {
        (屏幕坐标.X * 0.5f) + 世界x矩阵.X * ((屏幕坐标.X * 0.5f) / tanf(POV.FOV * M_PI / 360.0f)) / 世界x矩阵.Z,
        (屏幕坐标.Y * 0.5f) - 世界x矩阵.Y * ((屏幕坐标.X * 0.5f) / tanf(POV.FOV * M_PI / 360.0f)) / 世界x矩阵.Z,
    };
};

string 取FString(uint64_t PlayerName) {
    NSMutableString* FString = [NSMutableString string];
    for (int i = 0; i < 14; i++) {
        unichar 字节 = kfd.取物理<unichar>(PlayerName + i * 2);
        if (字节 == 0) break;
        [FString appendFormat:@"%c", 字节];
    };
    return [FString UTF8String];
};
