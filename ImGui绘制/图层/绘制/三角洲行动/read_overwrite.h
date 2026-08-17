#pragma once

#include <string>
#include <vector>
#include <cstring>
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
#include <sys/sysctl.h>

// iOS 上 mach/mach_vm.h 是 "#error mach_vm.h unsupported"（苹果禁用了这个头文件），
// 但 mach_vm_read_overwrite 的函数符号在 libsystem_kernel 里是存在的（神之眼巨魔原版
// 就是用 extern 声明这种方式读的，能正常读 64 位地址）。
// 这里 extern 声明绕过 #error，保持 mach_vm_read_overwrite（读 64 位地址）。
extern "C" {
    kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address,
                                         mach_vm_size_t size, mach_vm_address_t data,
                                         mach_vm_size_t *outsize);
}

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

// 读内存行（mach_vm_read_overwrite，能读 64 位地址；失败自动重试 3 次）
static bool 读内存行(uint64_t 地址, void *数据, size_t 大小) {
    if (!_task || !地址 || !数据 || !大小) return false;
    for (int 尝试 = 0; 尝试 < 3; 尝试++) {
        mach_vm_size_t out = 0;
        if (mach_vm_read_overwrite(_task, (mach_vm_address_t)地址, (mach_vm_size_t)大小,
                                   (mach_vm_address_t)数据, &out) == KERN_SUCCESS && out == 大小) {
            return true;
        }
    }
    return false;
}

// 写内存行（vm_write 是 iOS 标准 API，符号确定存在）
static bool 写内存行(uint64_t 地址, const void *数据, size_t 大小) {
    if (!_task || !地址 || !数据 || !大小) return false;
    return vm_write(_task, (vm_address_t)地址,
                    (vm_offset_t)数据, (mach_msg_type_number_t)大小) == KERN_SUCCESS;
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
