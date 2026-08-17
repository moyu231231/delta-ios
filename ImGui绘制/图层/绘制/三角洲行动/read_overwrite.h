#pragma once

#include <string>
#include <vector>
#include <cstring>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach-o/dyld_images.h>
#include <sys/sysctl.h>

static task_t _task = MACH_PORT_NULL;

static pid_t 取进程ID(std::string 进程名) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t len = 0;
    if (sysctl(mib, 4, nullptr, &len, nullptr, 0) < 0) return -1;
    auto *procs = (struct kinfo_proc *)malloc(len);
    if (!procs) return -1;
    if (sysctl(mib, 4, procs, &len, nullptr, 0) < 0) { free(procs); return -1; }
    pid_t result = -1;
    for (size_t i = 0, n = len / sizeof(struct kinfo_proc); i < n; i++) {
        if (进程名 == procs[i].kp_proc.p_comm) { result = procs[i].kp_proc.p_pid; break; }
    }
    free(procs);
    return result;
}

// 读内存行 (iOS 用 vm_read_overwrite, 不是 macOS 的 mach_vm_read_overwrite)
static bool 读内存行(uint64_t 地址, void *数据, size_t 大小) {
    if (!_task || !地址 || !数据 || !大小) return false;
    vm_size_t out = 0;
    if (vm_read_overwrite(_task, (vm_address_t)地址, (vm_size_t)大小,
                          (vm_address_t)数据, &out) != KERN_SUCCESS) return false;
    return out == 大小;
}

// 写内存 (iOS 用 vm_write, 不是 macOS 的 mach_vm_write)
static bool 写内存行(uint64_t 地址, const void *数据, size_t 大小) {
    if (!_task || !地址 || !数据 || !大小) return false;
    return vm_write(_task, (vm_address_t)地址,
                    (vm_offset_t)数据, (mach_msg_type_number_t)大小) == KERN_SUCCESS;
}

// 稳定读 (双重读校验, 防撕裂)
static bool 稳定读内存行(uint64_t 地址, void *数据, size_t 大小) {
    if (!数据 || !大小 || 大小 > 2048) return false;
    uint8_t 第一次[2048];
    uint8_t 第二次[2048];
    if (!读内存行(地址, 第一次, 大小)) return false;
    if (!读内存行(地址, 第二次, 大小)) return false;
    if (memcmp(第一次, 第二次, 大小) != 0) return false;
    memcpy(数据, 第一次, 大小);
    return true;
}

static uint64_t 取模块地址(pid_t 进程ID, std::string 模块名) {
    if (task_for_pid(mach_task_self(), 进程ID, &_task) != KERN_SUCCESS) return 0;

    task_dyld_info_data_t info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    if (task_info(_task, TASK_DYLD_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return 0;

    dyld_all_image_infos infos{};
    if (!读内存行(info.all_image_info_addr, &infos, sizeof(infos))) return 0;

    std::vector<dyld_image_info> images(infos.infoArrayCount);
    if (!读内存行((uint64_t)infos.infoArray, images.data(),
                sizeof(dyld_image_info) * infos.infoArrayCount)) return 0;

    for (auto &img : images) {
        char path[PATH_MAX]{};
        读内存行((uint64_t)img.imageFilePath, path, sizeof(path) - 1);
        std::string full(path);
        size_t slash = full.find_last_of('/');
        std::string name = (slash == std::string::npos) ? full : full.substr(slash + 1);
        if (name == 模块名) return (uint64_t)img.imageLoadAddress;
    }
    return 0;
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
