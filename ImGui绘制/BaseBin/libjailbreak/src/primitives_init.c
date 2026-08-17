#include "primitives_init.h"
#include <stdatomic.h>
#include <unistd.h>
#include <stdbool.h>

// External declarations (provided by main.c in production, mocks in tests)
extern int jbclient_initialize_primitives_internal(bool physrwPTE);
extern bool device_supports_physrw_pte(void);

// Atomic state: 0=UNINIT, 1=INITIALIZING, 2=READY
static _Atomic int g_prim_init_state = PRIM_UNINIT;

int primitives_ensure_initialized(void)
{
	int state = atomic_load_explicit(&g_prim_init_state, memory_order_acquire);

	// Fast path: already initialized
	if (state == PRIM_READY) return 0;

	// Try to become the initializer
	int expected = PRIM_UNINIT;
	if (atomic_compare_exchange_strong_explicit(
			&g_prim_init_state, &expected, PRIM_INITIALIZING,
			memory_order_acq_rel, memory_order_acquire)) {
		// Winner thread: perform actual initialization
		int r = jbclient_initialize_primitives_internal(device_supports_physrw_pte());

		if (r == 0) {
			atomic_store_explicit(&g_prim_init_state, PRIM_READY, memory_order_release);
		} else {
			// Failed: reset to UNINIT so future calls can retry
			atomic_store_explicit(&g_prim_init_state, PRIM_UNINIT, memory_order_release);
		}
		return r;
	}

	// Loser threads: spin-wait for winner to finish
	while ((state = atomic_load_explicit(&g_prim_init_state, memory_order_acquire))
		   == PRIM_INITIALIZING) {
		usleep(100);
	}

	return (state == PRIM_READY) ? 0 : -1;
}

void primitives_reset_init_state(void)
{
	atomic_store_explicit(&g_prim_init_state, PRIM_UNINIT, memory_order_release);
}

int primitives_get_init_state(void)
{
	return atomic_load_explicit(&g_prim_init_state, memory_order_acquire);
}
