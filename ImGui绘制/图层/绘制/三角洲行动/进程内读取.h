#pragma once

#include <cstring>
#include <vector>
#include <string>
#include <unistd.h>
#include <mach-o/dyld.h>

// ============================================================
//  进程内读取 (注入游戏进程后使用)
//  直接指针访问内存, 零跨进程特征 —— 没有 task port / mach_vm_read / 内核漏洞
//  ACE 在"读取"层面 100% 检测不到, 因为它根本不存在"跨进程读"这个动作
// ============================================================

static uint64_t 主程序基址 = 0;

static pid_t 取进程ID(std::string 进程名) {
    // 进程内: 当前进程就是游戏本身
    (void)进程名;
    return getpid();
}

// 拿主程序 (DeltaForceClient) 基址
static uint64_t 取主程序基址() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "DeltaForceClient")) {
            return (uint64_t)_dyld_get_image_header(i);
        }
    }
    // 兜底: image 0 就是主程序
    return (uint64_t)_dyld_get_image_header(0);
}

// 拿指定模块基址 (进程内遍历 dyld)
static uint64_t 取模块地址(pid_t 进程ID, std::string 模块名) {
    (void)进程ID;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name) {
            const char *base = strrchr(name, '/');
            base = base ? base + 1 : name;
            if (模块名 == base) return (uint64_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

// 进程内读: 直接 memcpy (正常内存访问)
static bool 读内存行(uint64_t 地址, void *数据, size_t 大小) {
    if (!地址 || !数据 || !大小) return false;
    memcpy(数据, (const void *)地址, 大小);
    return true;
}

// 进程内写: 直接 memcpy
static bool 写内存行(uint64_t 地址, const void *数据, size_t 大小) {
    if (!地址 || !数据 || !大小) return false;
    memcpy((void *)地址, 数据, 大小);
    return true;
}

// 稳定读: 双重读校验 (检测游戏侧并发写导致的撕裂值)
static bool 稳定读内存行(uint64_t 地址, void *数据, size_t 大小) {
    if (!数据 || !大小 || 大小 > 2048) return false;
    uint8_t a[2048], b[2048];
    if (!读内存行(地址, a, 大小)) return false;
    if (!读内存行(地址, b, 大小)) return false;
    if (memcmp(a, b, 大小) != 0) return false;
    memcpy(数据, a, 大小);
    return true;
}

template <typename 类型>
类型 读内存(uint64_t 地址) {
    类型 result{};
    读内存行(地址, &result, sizeof(类型));
    return result;
}

template <typename 类型>
类型 读内存列(uint64_t 地址, std::vector<uint64_t> 数组) {
    if (数组.empty()) return 类型();
    for (size_t i = 0; i < 数组.size() - 1; i++) {
        地址 = 读内存<uint64_t>(地址 + 数组[i]);
        if (!地址) return 类型();
    }
    return 读内存<类型>(地址 + 数组.back());
}

template <typename 类型>
bool 写内存(uint64_t 地址, const 类型 &值) {
    return 写内存行(地址, &值, sizeof(类型));
}
