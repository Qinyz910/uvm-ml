# C Reference Memory Model

The `models/c_reference` directory provides a portable C implementation of the RTL
memory subsystem. It mirrors the SystemVerilog design by offering:

- Fully associative virtual-to-physical address translation with a round-robin TLB
- Backing store with per-byte write masking
- Transaction status codes that align with the RTL responses
- Control APIs to preload translations, reset state, and query TLB status

This model is intended for use in unit-level validation, scoreboarding, and future
integration with the SystemC verification environment.

## Directory Layout

```
models/c_reference/
├── include/
│   └── memory_model.h        # Public API
├── src/
│   └── memory_model.c        # Implementation
└── tests/
    └── memory_model_tests.c  # Standalone regression tests
```

## Build & Test

The top-level `Makefile` exposes dedicated targets for the C reference model:

```bash
# Build the static library and run the unit tests
default$ make c_reference

# Re-run just the unit tests (build is implicit)
default$ make c_reference-test

# Remove generated objects and binaries
default$ make c_reference-clean
```

Build artefacts are placed under `build/c_reference/`, including
`libmemory_model.a` and the `memory_model_tests` executable.

> **Note:** The model requires a C11-compliant compiler (the default is `gcc`).

## API Overview

The public interface is defined in [`memory_model.h`](../models/c_reference/include/memory_model.h).
Key entry points include:

| Function | Description |
| --- | --- |
| `memory_model_config_default` | Returns the default hardware-compatible configuration |
| `memory_model_create` / `memory_model_destroy` | Allocate or release a model instance |
| `memory_model_reset` | Restore memory contents and the TLB to power-on defaults |
| `memory_model_load_tlb` | Insert a virtual-to-physical mapping using a round-robin policy |
| `memory_model_translate` | Perform translation without touching memory |
| `memory_model_read` / `memory_model_write` | Issue masked transactions using virtual addresses |
| `memory_model_active_entries` | Query the number of valid TLB entries |
| `memory_model_tlb_write_index` | Expose the next insertion index (mirrors RTL output) |

Transaction results use `memory_model_status_t`, which aligns with the RTL package:

- `MEMORY_MODEL_STATUS_OK`
- `MEMORY_MODEL_STATUS_ERR_ADDR`
- `MEMORY_MODEL_STATUS_ERR_ACCESS`
- `MEMORY_MODEL_STATUS_ERR_WRITE`
- `MEMORY_MODEL_STATUS_PENDING`

Control functions return `memory_model_error_t` values to distinguish configuration
or allocation issues from transaction-level responses.

## Usage Example

```c
#include "memory_model.h"
#include <stdio.h>
#include <inttypes.h>

int main(void) {
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "Failed to create memory model\n");
        return 1;
    }

    /* Preload a 4 KiB page mapping. */
    memory_model_load_tlb(model, 0x00001000u, 0x00002000u);

    /* Write a full 64-bit word. */
    memory_model_status_t status = memory_model_write(
        model, 0x00001020u, 0xFFu, 0x1122334455667788ULL);

    if (status != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "Write failed: %d\n", status);
        memory_model_destroy(model);
        return 1;
    }

    uint64_t data = 0ULL;
    status = memory_model_read(model, 0x00001020u, 0xFFu, &data);
    if (status == MEMORY_MODEL_STATUS_OK) {
        printf("Readback: 0x%016" PRIx64 "\n", data);
    }

    memory_model_destroy(model);
    return 0;
}
```

The example above mirrors the semantics of the RTL testbench: virtual addresses are
translated prior to accessing the backing store, and per-byte masks determine which
bytes participate in a transaction. Passing a mask of zero performs translation but
leaves memory untouched (matching the RTL behaviour).

## Unit Tests

`memory_model_tests.c` exercises the major functional paths:

- Basic read/write parity with the RTL default configuration
- Byte-masked writes and reads
- Error reporting for unmapped virtual addresses
- TLB pointer wrap-around and overwrite behaviour
- Reset semantics and translation of arbitrary offsets

Running `make c_reference` compiles these tests and executes them automatically.
The binary prints a concise `gtest`-style log summarising pass/fail status and
returns a non-zero exit code on failure, enabling straightforward CI integration.

## Integration Notes

- The model is written in portable C11 and can be linked from C or C++ code. The
  header supplies `extern "C"` guards for C++ consumers.
- The API uses fixed-width integer types to maintain bit-accurate behaviour across
  platforms.
- The static library can be linked directly into forthcoming SystemC components or
  Python-based scoreboards without modification.

For additional details on the hardware design, consult
[`docs/rtl_memory.md`](./rtl_memory.md).
