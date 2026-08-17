#include "translation.h"
#include "primitives.h"
#include "kernel.h"
#include "info.h"
#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>

#define LOG_PATH "/var/mobile/Documents/optimized_uva.txt"
#define SET_CAP  (1u << 16)   // 65536，2的幂
#define MIN_HEX_OFFSET 0x4   // “一位数偏移不要”

static int g_fd = -1;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

// 线程内“上一次地址”，避免多线程把顺序搅乱
static __thread uint64_t tls_last_addr = 0;

// 去重集合：存 delta（用 0 表示空槽，所以我们跳过 delta==0）
static uint64_t g_seen_delta[SET_CAP];

static inline uint64_t hash64(uint64_t x) {
    x += 0x9e3779b97f4a7c15ULL;
    x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ULL;
    x = (x ^ (x >> 27)) * 0x94d049bb133111ebULL;
    return x ^ (x >> 31);
}

static void log_unique_delta(uint64_t addr) {
    if (!addr) return;

    uint64_t prev = tls_last_addr;
    tls_last_addr = addr;

    if (!prev) return; // 第一次没有“上个地址”，不记录

    int64_t d = (int64_t)(addr - prev);
    if (d == 0) return;

    uint64_t ad = (d > 0) ? (uint64_t)d : (uint64_t)(-d);
    if (ad < MIN_HEX_OFFSET) return; // 过滤“一位数偏移”

    uint64_t key = (uint64_t)d; // 保留正负号信息

    pthread_mutex_lock(&g_lock);

    if (g_fd < 0) g_fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (g_fd < 0) { pthread_mutex_unlock(&g_lock); return; }

    uint64_t idx = hash64(key) & (SET_CAP - 1);
    for (uint64_t i = 0; i < SET_CAP; i++) {
        uint64_t cur = g_seen_delta[idx];
        if (cur == key) { pthread_mutex_unlock(&g_lock); return; } // 已记录
        if (cur == 0) {
            g_seen_delta[idx] = key;

            char line[200];
            if (d > 0) {
                int n = snprintf(line, sizeof(line),
                    "发现偏移：+0x%llx（上次=0x%llx，本次=0x%llx）\n",
                    (unsigned long long)ad,
                    (unsigned long long)prev,
                    (unsigned long long)addr
                );
                if (n > 0) (void)write(g_fd, line, (size_t)n);
            } else {
                int n = snprintf(line, sizeof(line),
                    "发现偏移：-0x%llx（上次=0x%llx，本次=0x%llx）\n",
                    (unsigned long long)ad,
                    (unsigned long long)prev,
                    (unsigned long long)addr
                );
                if (n > 0) (void)write(g_fd, line, (size_t)n);
            }

            pthread_mutex_unlock(&g_lock);
            return;
        }
        idx = (idx + 1) & (SET_CAP - 1);
    }

    pthread_mutex_unlock(&g_lock);
}
struct tt_level {
	uint64_t offMask;
	uint64_t shift;
	uint64_t indexMask;
	uint64_t validMask;
	uint64_t typeMask;
	uint64_t typeBlock;
};
struct tt_level arm_tt_level[4];

// Address translation physical <-> virtual

uint64_t phystokv(uint64_t pa)
{
	const uint64_t PTOV_TABLE_SIZE = 8;
	struct ptov_table_entry {
		uint64_t pa;
		uint64_t va;
		uint64_t len;
	} ptov_table[PTOV_TABLE_SIZE];
	kreadbuf(ksymbol(ptov_table), &ptov_table[0], sizeof(ptov_table));

	for (uint64_t i = 0; (i < PTOV_TABLE_SIZE) && (ptov_table[i].len != 0); i++) {
		if ((pa >= ptov_table[i].pa) && (pa < (ptov_table[i].pa + ptov_table[i].len))) {
			return pa - ptov_table[i].pa + ptov_table[i].va;
		}
	}

	return pa - kconstant(physBase) + kconstant(virtBase);
}

uint64_t vtophys_lvl(uint64_t tte_ttep, uint64_t va, uint64_t *leaf_level, uint64_t *leaf_tte_ttep)
{
	errno = 0;
	const uint64_t ROOT_LEVEL = PMAP_TT_L1_LEVEL;
	const uint64_t LEAF_LEVEL = *leaf_level;

	uint64_t pa = 0;

	bool physical = !(bool)(tte_ttep & 0xf000000000000000);

	for (uint64_t curLevel = ROOT_LEVEL; curLevel <= LEAF_LEVEL; curLevel++) {
		if (curLevel > PMAP_TT_L3_LEVEL) {
			errno = 1041;
			return 0;
		}

		struct tt_level *lvlp = &arm_tt_level[curLevel];
		uint64_t tteIndex = (va & lvlp->indexMask) >> lvlp->shift;
		uint64_t tteEntry = 0;
		if (physical) {
			uint64_t tte_pa = tte_ttep + (tteIndex * sizeof(uint64_t));
			tteEntry = physread64(tte_pa);
			if (leaf_tte_ttep) *leaf_tte_ttep = tte_pa;
			if (leaf_level) *leaf_level = curLevel;
		}
		else if (gPrimitives.kreadbuf && !physical) {
			uint64_t tte_va = tte_ttep + (tteIndex * sizeof(uint64_t));
			tteEntry = kread64(tte_va);
			if (leaf_tte_ttep) *leaf_tte_ttep = tte_va;
			if (leaf_level) *leaf_level = curLevel;
		}
		else {
			printf("WARNING: Failed %s translation, no function to do it.\n", physical ? "physical" : "virtual");
			errno = 1043;
			return 0;
		}

		if ((tteEntry & lvlp->validMask) != lvlp->validMask) {
			errno = 1042;
			return 0;
		}

		if ((tteEntry & lvlp->typeMask) == lvlp->typeBlock) {
			// Found block mapping, no matter what level we are in, this is the end
			return ((tteEntry & ARM_TTE_PA_MASK & ~lvlp->offMask) | (va & lvlp->offMask));
		}

		if (physical) {
			tte_ttep = tteEntry & ARM_TTE_TABLE_MASK;
		}
		else {
			tte_ttep = phystokv(tteEntry & ARM_TTE_TABLE_MASK);
		}
	}

	// If we end up here, it means we did not find a block mapping
	// In this case, return the last page table address we traversed
	return tte_ttep;
}

uint64_t vtophys(uint64_t tte_ttep, uint64_t va)
{
    log_unique_delta(va);
	uint64_t level = PMAP_TT_L3_LEVEL;
	return vtophys_lvl(tte_ttep, va, &level, NULL);
}

uint64_t kvtophys(uint64_t va)
{
	return vtophys(kconstant(cpuTTEP), va);
}

void libjailbreak_translation_init(void)
{
	// A9+: Kernel uses 16K pages
	if (vm_real_kernel_page_size == 0x4000) {
		arm_tt_level[0] = (struct tt_level){
			.offMask = ARM_16K_TT_L0_OFFMASK,
			.shift = ARM_16K_TT_L0_SHIFT,
			.indexMask = ARM_16K_TT_L0_INDEX_MASK,
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_BLOCK,
		};
		arm_tt_level[1] = (struct tt_level){
			.offMask = ARM_16K_TT_L1_OFFMASK,
			.shift = ARM_16K_TT_L1_SHIFT,
			.indexMask = kconstant(ARM_TT_L1_INDEX_MASK),
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_BLOCK,
		};
		arm_tt_level[2] = (struct tt_level){
			.offMask = ARM_16K_TT_L2_OFFMASK,
			.shift = ARM_16K_TT_L2_SHIFT,
			.indexMask = ARM_16K_TT_L2_INDEX_MASK,
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_BLOCK,
		};
		arm_tt_level[3] = (struct tt_level){
			.offMask = ARM_16K_TT_L3_OFFMASK,
			.shift = ARM_16K_TT_L3_SHIFT,
			.indexMask = ARM_16K_TT_L3_INDEX_MASK,
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_L3BLOCK,
		};
	}
	// A8: Kernel uses 4k pages
	else if (vm_real_kernel_page_size == 0x1000) {
		arm_tt_level[0] = (struct tt_level){
			.offMask = ARM_4K_TT_L0_OFFMASK,
			.shift = ARM_4K_TT_L0_SHIFT,
			.indexMask = ARM_4K_TT_L0_INDEX_MASK,
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_BLOCK,
		};
		arm_tt_level[1] = (struct tt_level){
			.offMask = ARM_4K_TT_L1_OFFMASK,
			.shift = ARM_4K_TT_L1_SHIFT,
			.indexMask = kconstant(ARM_TT_L1_INDEX_MASK),
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_BLOCK,
		};
		arm_tt_level[2] = (struct tt_level){
			.offMask = ARM_4K_TT_L2_OFFMASK,
			.shift = ARM_4K_TT_L2_SHIFT,
			.indexMask = ARM_4K_TT_L2_INDEX_MASK,
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_BLOCK,
		};
		arm_tt_level[3] = (struct tt_level){
			.offMask = ARM_4K_TT_L3_OFFMASK,
			.shift = ARM_4K_TT_L3_SHIFT,
			.indexMask = ARM_4K_TT_L3_INDEX_MASK,
			.validMask = ARM_TTE_VALID,
			.typeMask = ARM_TTE_TYPE_MASK,
			.typeBlock = ARM_TTE_TYPE_L3BLOCK,
		};
	}

	gPrimitives.phystokv = phystokv;
	gPrimitives.vtophys  = vtophys;
}
