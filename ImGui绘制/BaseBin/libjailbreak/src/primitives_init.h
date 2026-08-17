#ifndef PRIMITIVES_INIT_H
#define PRIMITIVES_INIT_H

#include <stdbool.h>

// Thread-safe lazy initialization states
enum {
	PRIM_UNINIT       = 0,
	PRIM_INITIALIZING = 1,
	PRIM_READY        = 2
};

// Thread-safe lazy initialization for kernel primitives.
// Multiple threads may call this concurrently; only one performs actual init.
// Returns 0 on success, -1 on failure (retryable on next call).
int primitives_ensure_initialized(void);

// Reset initialization state (for testing only)
void primitives_reset_init_state(void);

// Get current initialization state (for testing/diagnostics)
int primitives_get_init_state(void);

#endif
