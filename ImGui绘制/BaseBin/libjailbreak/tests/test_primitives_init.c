// TDD Test: Thread-safe lazy initialization for kernel primitives
// Compile: cc -std=c11 -pthread -o test_primitives_init test_primitives_init.c ../src/primitives_init.c -I../src -DPRIMITIVES_TESTING
// Run: ./test_primitives_init

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>
#include "primitives_init.h"

// ========== Mock Infrastructure ==========

static _Atomic int g_mock_init_call_count = 0;
static _Atomic int g_mock_init_return_value = 0;
static _Atomic int g_mock_init_delay_us = 0;  // simulate slow init

// Mock: replaces jbclient_initialize_primitives_internal
int jbclient_initialize_primitives_internal(bool physrwPTE)
{
	atomic_fetch_add(&g_mock_init_call_count, 1);

	int delay = atomic_load(&g_mock_init_delay_us);
	if (delay > 0) {
		usleep(delay);
	}

	return atomic_load(&g_mock_init_return_value);
}

// Mock: replaces device_supports_physrw_pte
bool device_supports_physrw_pte(void)
{
	return false;
}

static void reset_mocks(void)
{
	atomic_store(&g_mock_init_call_count, 0);
	atomic_store(&g_mock_init_return_value, 0);
	atomic_store(&g_mock_init_delay_us, 0);
	primitives_reset_init_state();
}

// ========== Test Cases ==========

// Test 1: Single thread init succeeds, state transitions 0 → 2
void test_single_thread_init(void)
{
	reset_mocks();

	assert(primitives_get_init_state() == PRIM_UNINIT);

	int ret = primitives_ensure_initialized();

	assert(ret == 0);
	assert(primitives_get_init_state() == PRIM_READY);
	assert(atomic_load(&g_mock_init_call_count) == 1);

	printf("  [PASS] test_single_thread_init\n");
}

// Test 2: Second call returns immediately without re-initializing
void test_double_call_no_reinit(void)
{
	reset_mocks();

	int ret1 = primitives_ensure_initialized();
	assert(ret1 == 0);
	assert(atomic_load(&g_mock_init_call_count) == 1);

	int ret2 = primitives_ensure_initialized();
	assert(ret2 == 0);
	assert(atomic_load(&g_mock_init_call_count) == 1); // still 1, not 2

	printf("  [PASS] test_double_call_no_reinit\n");
}

// Test 3: Init failure returns -1, allows retry on next call
void test_init_failure_retry(void)
{
	reset_mocks();
	atomic_store(&g_mock_init_return_value, -1); // make init fail

	int ret1 = primitives_ensure_initialized();
	assert(ret1 == -1);
	assert(primitives_get_init_state() == PRIM_UNINIT); // reset to 0, not stuck
	assert(atomic_load(&g_mock_init_call_count) == 1);

	// Fix the mock, retry should succeed
	atomic_store(&g_mock_init_return_value, 0);

	int ret2 = primitives_ensure_initialized();
	assert(ret2 == 0);
	assert(primitives_get_init_state() == PRIM_READY);
	assert(atomic_load(&g_mock_init_call_count) == 2);

	printf("  [PASS] test_init_failure_retry\n");
}

// Test 4: Multi-thread race — only one thread performs init
#define RACE_THREAD_COUNT 16

static void *race_thread_fn(void *arg)
{
	int *result = (int *)arg;
	*result = primitives_ensure_initialized();
	return NULL;
}

void test_multithread_race(void)
{
	reset_mocks();
	atomic_store(&g_mock_init_delay_us, 50000); // 50ms to make race window obvious

	pthread_t threads[RACE_THREAD_COUNT];
	int results[RACE_THREAD_COUNT];

	for (int i = 0; i < RACE_THREAD_COUNT; i++) {
		pthread_create(&threads[i], NULL, race_thread_fn, &results[i]);
	}

	for (int i = 0; i < RACE_THREAD_COUNT; i++) {
		pthread_join(threads[i], NULL);
	}

	// All threads should get success
	for (int i = 0; i < RACE_THREAD_COUNT; i++) {
		assert(results[i] == 0);
	}

	// Only ONE thread should have called the actual init
	assert(atomic_load(&g_mock_init_call_count) == 1);
	assert(primitives_get_init_state() == PRIM_READY);

	printf("  [PASS] test_multithread_race (16 threads, 1 init call)\n");
}

// Test 5: Multi-thread concurrent reads after init — all return 0
#define READ_THREAD_COUNT 32

static void *read_thread_fn(void *arg)
{
	int *result = (int *)arg;
	*result = primitives_ensure_initialized();
	return NULL;
}

void test_concurrent_reads_after_init(void)
{
	reset_mocks();

	// Pre-initialize
	int ret = primitives_ensure_initialized();
	assert(ret == 0);

	pthread_t threads[READ_THREAD_COUNT];
	int results[READ_THREAD_COUNT];

	for (int i = 0; i < READ_THREAD_COUNT; i++) {
		pthread_create(&threads[i], NULL, read_thread_fn, &results[i]);
	}

	for (int i = 0; i < READ_THREAD_COUNT; i++) {
		pthread_join(threads[i], NULL);
	}

	for (int i = 0; i < READ_THREAD_COUNT; i++) {
		assert(results[i] == 0);
	}

	// Init should only have been called once (during pre-init)
	assert(atomic_load(&g_mock_init_call_count) == 1);

	printf("  [PASS] test_concurrent_reads_after_init (32 threads)\n");
}

// Test 6: Multi-thread race with failure — losers see failure, retry works
void test_multithread_race_failure(void)
{
	reset_mocks();
	atomic_store(&g_mock_init_return_value, -1);
	atomic_store(&g_mock_init_delay_us, 30000); // 30ms

	pthread_t threads[8];
	int results[8];

	for (int i = 0; i < 8; i++) {
		pthread_create(&threads[i], NULL, race_thread_fn, &results[i]);
	}

	for (int i = 0; i < 8; i++) {
		pthread_join(threads[i], NULL);
	}

	// All threads should see failure
	for (int i = 0; i < 8; i++) {
		assert(results[i] == -1);
	}

	// State should be back to UNINIT (retryable)
	assert(primitives_get_init_state() == PRIM_UNINIT);

	// Fix mock and retry
	atomic_store(&g_mock_init_return_value, 0);
	int ret = primitives_ensure_initialized();
	assert(ret == 0);
	assert(primitives_get_init_state() == PRIM_READY);

	printf("  [PASS] test_multithread_race_failure\n");
}

// ========== Main ==========

int main(void)
{
	printf("=== P0 TDD: Thread-Safe Lazy Initialization ===\n\n");

	test_single_thread_init();
	test_double_call_no_reinit();
	test_init_failure_retry();
	test_multithread_race();
	test_concurrent_reads_after_init();
	test_multithread_race_failure();

	printf("\n=== ALL 6 TESTS PASSED ===\n");
	return 0;
}
