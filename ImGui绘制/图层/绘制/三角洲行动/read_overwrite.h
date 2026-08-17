#pragma once

#include <string>
#include <vector>
#include <cstring>
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
#include <sys/sysctl.h>

// ============================================================
//  一体化内核读取（libjailbreak 内核读写原语）
//  流程：先跑内核漏洞（ExecutionKernel）→ proc_find 拿游戏 proc
//        → 之后读/写内存全部走内核原语 proc_vreadbuf / proc_vwritebuf
//  不依赖 task_for_pid / mach_vm_read（这两个会被 ACE 检测）
// ============================================================

// libjailbreak 导出的内核读写原语（内核漏洞跑起来后可用）
extern "C" {
    uint64_t proc_find(pid_t pid);
    int proc_vreadbuf(uint64_t proc, const void *addr, void *outdata, size_t datalen);
    int proc_vwritebuf(uint64_t proc, const void *addr, const void *indata, size_t datalen);
}

static uint64_t 游戏proc = 0;   // 游戏进程的 proc 结构（内核读入口）

// 初始化内核读取：proc_find 拿游戏进程 proc（调用前必须先跑完内核漏洞 ExecutionKernel）
static bool 初始化内核读取(pid_t 游戏pid) {
    if (游戏pid <= 0) return false;
    游戏proc = proc_find(游戏pid);
    return 游戏proc != 0;
}

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

// 通过 processor_set_tasks 遍历拿 task port（绕过 task_for_pid 的 AMFI 限制）
// 纯巨魔 root 权限即可，不需要越狱 —— 神之眼巨魔原版方案
static kern_return_t task_for_pid_workaround(pid_t pid, mach_port_t *task_port) {
    kern_return_t kr;
    mach_port_t host_priv = mach_host_self();
    processor_set_name_t default_set;
    processor_set_t priv_set;
    task_array_t task_list;
    mach_msg_type_number_t task_count;
    int current_pid;

    kr = processor_set_default(host_priv, &default_set);
    if (kr != KERN_SUCCESS) return kr;

    kr = host_processor_set_priv(host_priv, default_set, &priv_set);
    if (kr != KERN_SUCCESS) return kr;

    kr = processor_set_tasks(priv_set, &task_list, &task_count);
    if (kr != KERN_SUCCESS) return kr;

    for (mach_msg_type_number_t i = 0; i < task_count; i++) {
        pid_for_task(task_list[i], &current_pid);
        if (current_pid == pid) {
            *task_port = task_list[i];
            return KERN_SUCCESS;
        }
    }
    return KERN_FAILURE;
}

// 读内存行（内核读 proc_vreadbuf，失败自动重试 3 次）
static bool 读内存行(uint64_t 地址, void *数据, size_t 大小) {
    if (!游戏proc || !地址 || !数据 || !大小) return false;
    for (int 尝试 = 0; 尝试 < 3; 尝试++) {
        if (proc_vreadbuf(游戏proc, (const void *)地址, 数据, 大小) == 0) return true;
    }
    return false;
}

// 写内存行（内核写 proc_vwritebuf）
static bool 写内存行(uint64_t 地址, const void *数据, size_t 大小) {
    if (!游戏proc || !地址 || !数据 || !大小) return false;
    return proc_vwritebuf(游戏proc, (const void *)地址, 数据, 大小) == 0;
}

// 取模块地址（内核读遍历 dyld）
static uint64_t 取模块地址(pid_t 进程ID, std::string 模块名) {
    // 用 processor_set_tasks 遍历拿 task（绕过 task_for_pid，纯巨魔 root 可用，不依赖越狱）
    task_t task = MACH_PORT_NULL;
    if (task_for_pid_workaround(进程ID, &task) != KERN_SUCCESS) return 0;

    task_dyld_info_data_t info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    if (task_info(task, TASK_DYLD_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return 0;

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
