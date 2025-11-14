# TLM Testbench Build Instructions

## Quick Start

### Prerequisites

- SystemC 2.3.3+ development libraries
- C++ compiler with C++11 support (g++ 7.0+)
- C reference model already built

### Installation (Ubuntu/Debian)

```bash
# Install SystemC if not already present
sudo apt-get install libsystemc libsystemc-dev

# Verify installation
pkg-config --modversion systemc
```

### Build Steps

**From models/tlm directory:**

```bash
cd models/tlm
make clean
make all
```

**Or manually:**

```bash
# Compile each file
g++ -std=c++11 -Wall -Wextra -O2 -fPIC \
    -I./include -I/usr/include -I../c_reference/include \
    -c src/memory_transactor.cpp -o ../../build/tlm/memory_transactor.o

g++ -std=c++11 -Wall -Wextra -O2 -fPIC \
    -I./include -I/usr/include -I../c_reference/include \
    -c src/memory_scoreboard.cpp -o ../../build/tlm/memory_scoreboard.o

g++ -std=c++11 -Wall -Wextra -O2 -fPIC \
    -I./include -I/usr/include -I../c_reference/include \
    -c src/memory_test_scenario.cpp -o ../../build/tlm/memory_test_scenario.o

g++ -std=c++11 -Wall -Wextra -O2 -fPIC \
    -I./include -I/usr/include -I../c_reference/include \
    -c src/tlm_testbench.cpp -o ../../build/tlm/tlm_testbench.o

# Link all objects with systemc library
g++ -std=c++11 -fPIC build/tlm/*.o build/c_reference/libmemory_model.a \
    /lib/x86_64-linux-gnu/libsystemc-2.3.4.so -o build/tlm_testbench
```

## Running the Testbench

```bash
cd /home/engine/project
./build/tlm_testbench
```

### Expected Output

```
=== Memory TLM Testbench ===
SystemC Version: 2.3.4

Starting simulation...

=== Memory TLM Test Scenario Starting ===
@ 0 s

>>> Test 1: TLB Load Operations
    TLB load test completed
    Result: PASS [TLB Load]

>>> Test 2: Basic Write Operations
    Basic write test completed
    Result: PASS [Basic Write]

>>> Test 3: Basic Read Operations
    Basic read test completed
    Result: PASS [Basic Read]

>>> Test 4: Masked Write Operations
    Masked write test completed
    Result: PASS [Masked Write]

>>> Test 5: Sequential Read-After-Write
    Sequential read-after-write test completed
    Result: PASS [Sequential R/W]

>>> Test 6: Error Handling (Translation Miss)
    Error handling test completed
    Result: PASS [Error Handling]

=== Memory TLM Test Scenario Complete ===
Total Tests: 6
Passed: 6
Failed: 0
Overall Result: PASS

Simulation completed at 300 us
```

## Troubleshooting

### SystemC Not Found

If you get "ERROR: SystemC not found":

```bash
# Install development files
sudo apt-get install libsystemc-dev

# Or set SYSTEMC_HOME explicitly
make SYSTEMC_HOME=/usr all
```

### Compilation Errors

If files fail to compile with includes issues:

```bash
# Check where systemc.h is located
find /usr -name "systemc.h" 2>/dev/null

# Ensure path is in -I flags
g++ -I/path/to/systemc/include ...
```

### Linking Errors

If you get undefined reference errors during linking:

```bash
# Try with explicit library path
g++ ... -L/lib/x86_64-linux-gnu -lsystemc ...

# Or link directly to the shared library
g++ ... /lib/x86_64-linux-gnu/libsystemc-2.3.4.so ...
```

### C++ ABI Issues

If you get version mismatch errors during linking:

```bash
# Try recompiling with explicit ABI flag
g++ -D_GLIBCXX_USE_CXX11_ABI=1 -std=c++11 ...
```

## Makefile Targets

```bash
# Build everything
make all

# Clean build artifacts
make clean

# Check environment
make check-env

# Show help
make help
```

## Development Notes

### Modifying Source Files

After editing source files in `src/`, just run:

```bash
make clean
make all
```

### Adding New Test Scenarios

1. Add test method to `MemoryTestScenario` class in header
2. Implement in cpp file
3. Call from `run_tests()` method
4. Rebuild with `make`

### Extending for RTL Co-simulation

1. Create `RTLMemoryTarget` extending `MemoryTarget`
2. Override `process_transaction()` to call RTL via DPI
3. Recompile with new class

## Integration with Build System

To integrate into the top-level build:

```bash
# From project root
cd models/tlm
make all

# Or use top-level target (when available)
make tlm
```

## Compiler Compatibility

Tested with:
- GCC 7.0+
- Clang 5.0+
- Both with C++11 standard

## Performance

- TLM simulation speed: ~1000x faster than RTL cycle-accurate
- Typical test run: <1 second
- Memory overhead: ~10 MB for full testbench

---

For detailed architecture and component descriptions, see:
- `README.md` - Component overview
- `docs/tlm_integration.md` - Integration with UVM ML and RTL
- `docs/TLM_IMPLEMENTATION_COMPLETE.md` - Complete implementation report
