# Hardware Verification Project

This repository contains a comprehensive hardware verification framework that integrates RTL design, SystemC/TLM modeling, and UVM-based verification components with end-to-end DPI connectivity.

## Project Goals

- Provide a unified verification environment for complex digital designs
- Support multiple abstraction levels from RTL to transaction-level modeling
- Enable reusable verification components using UVM methodology
- Facilitate co-simulation between SystemVerilog and SystemC components
- Deliver complete end-to-end verification flow with automated regression

## Repository Structure

```
.
├── rtl/                    # Register-Transfer Level designs
│   ├── src/               # RTL source files
│   │   ├── memory.sv      # Main memory module with TLB
│   │   └── memory_dpi_bridge.sv  # DPI bridge wrapper
│   ├── include/           # Header files and packages
│   └── tb/                # Testbench components
├── verification/          # Verification environment
│   └── uvm_ml/           # UVM-ML (Multi-Language) components
│       ├── agents/       # UVM agents
│       │   └── mem_agent/  # Memory agent with DPI driver
│       ├── envs/         # UVM environments
│       ├── sequences/    # Test sequences
│       ├── tests/        # Test cases
│       └── tb/           # Integrated testbenches
├── models/               # C/C++ and SystemC models
│   ├── tlm/             # Transaction-Level Models
│   │   ├── include/      # DPI bridge and transactors
│   │   └── src/         # TLM implementations
│   ├── c_reference/      # Pure C/C++ reference models
│   └── systemc/         # SystemC implementation models
├── common/              # Shared utilities and interfaces
│   ├── memory_dpi.h     # DPI interface header
│   └── memory_dpi.c     # DPI implementation
├── scripts/             # Automation scripts
│   ├── run_regression.sh  # Full regression suite
│   └── quick_test.sh     # Quick validation
├── docs/                # Documentation
├── Makefile            # Build orchestration
└── README.md           # This file
```

## Toolchain Requirements

### Required Tools
- **SystemVerilog Simulator**: VCS, Questa/ModelSim, Xcelium, or equivalent
- **SystemC 2.3.3+**: IEEE 1666-2011 compliant SystemC installation
- **TLM 2.0**: Transaction-Level Modeling standard
- **UVM-ML**: Universal Verification Methodology Multi-Language support
- **C++ Compiler**: GCC 7.0+ or Clang 5.0+ with C++11 support
- **Make**: GNU Make 3.8+ or equivalent

### Optional Tools
- **Doxygen**: For API documentation generation
- **Python 3.8+**: For additional scripts and utilities

## Quick Start

### 1. Environment Setup

```bash
# Set SystemC installation path
export SYSTEMC_HOME=/usr/local/systemc-2.3.3

# Set UVM-ML installation path (optional)
export UVM_ML_HOME=/opt/uvm-ml

# Set preferred simulator
export SIMULATOR=vcs  # or questa, xcelium
```

### 2. Quick Validation Test

```bash
# Run quick validation to verify setup
./scripts/quick_test.sh
```

This script validates:
- C reference model compilation and tests
- TLM component building
- UVM environment compilation
- Basic smoke test execution
- DPI interface compilation

### 3. Build All Components

```bash
# Build everything
make all

# Or build specific components
make rtl           # Build RTL designs
make models        # Build SystemC/TLM models
make models-dpi    # Build DPI-enabled models
make verification  # Build UVM verification environment
make c_reference   # Build C reference model
```

### 4. Run Verification

#### Quick Smoke Test
```bash
make sim-uvm UVM_TESTNAME=smoke_test
```

#### Full Regression Suite
```bash
./scripts/run_regression.sh
```

#### Specific Test Types
```bash
# Smoke tests only
./scripts/run_regression.sh --smoke-only

# Random tests with specific seed
./scripts/run_regression.sh --random-only -r 12345

# With waveform generation
./scripts/run_regression.sh -w
```

## Detailed Verification Flow

### 1. RTL Design Integration

The verification flow starts with the RTL memory module (`rtl/src/memory.sv`) which provides:

- **Virtual-to-Physical Address Translation**: Using page table-based TLB
- **Read/Write Operations**: With byte-level masking and status reporting
- **TLB Management**: Runtime loading of translation entries
- **Error Handling**: Translation miss and access violation detection

### 2. DPI Bridge Connection

The DPI bridge (`rtl/src/memory_dpi_bridge.sv`) provides a C-callable interface:

```c
// Read operation via DPI
mem_dpi_status_e memory_dpi_read(uint64_t virt_addr, uint8_t byte_mask, 
                                uint64_t* data, uint32_t* timestamp);

// Write operation via DPI
mem_dpi_status_e memory_dpi_write(uint64_t virt_addr, uint8_t byte_mask,
                                 uint64_t data, uint32_t* timestamp);

// TLB load operation via DPI
mem_dpi_status_e memory_dpi_tlb_load(uint64_t virt_base, uint64_t phys_base,
                                     uint32_t* timestamp);
```

### 3. TLM Environment

The TLM environment (`models/tlm/`) provides:

- **MemoryInitiator**: Generates transactions from test scenarios
- **MemoryDPIBridge**: Connects TLM to RTL via DPI
- **MemoryScoreboard**: Validates responses against reference model
- **MemoryTestScenario**: Executes comprehensive test cases

### 4. UVM-ML Integration

The UVM environment (`verification/uvm_ml/`) includes:

- **mem_dpi_driver**: Drives transactions via DPI instead of generating random responses
- **mem_enhanced_monitor**: Collects transactions with functional coverage
- **mem_scoreboard**: Compares RTL responses with C reference model expectations
- **Enhanced test sequences**: Smoke, stress, and edge case testing

### 5. End-to-End Verification

The complete flow connects:

```
UVM Test Sequences → UVM Driver → DPI Bridge → RTL Memory Module → DPI Bridge → UVM Monitor → UVM Scoreboard
                                      ↘
                                       C Reference Model (for golden reference)
```

## Test Results and Coverage

### Functional Coverage

The enhanced monitor collects coverage for:

- **Operation Types**: Read, Write, TLB Load
- **Address Ranges**: Low, mid, high memory regions
- **Boundary Conditions**: Page boundaries, alignment
- **Byte Masks**: Full, partial, single-byte operations
- **Status Codes**: Success and error conditions
- **Translation Scenarios**: Hit/miss patterns

### Regression Categories

#### Smoke Tests
- Basic functionality validation
- TLB load and read-after-write
- Error handling verification

#### Directed Tests
- Boundary condition testing
- Edge case validation
- Translation miss scenarios

#### Random Tests
- Stress testing with random addresses
- Long-duration random sequences
- Corner case exploration

### Coverage Goals

- **Operation Coverage**: >95%
- **Address Space Coverage**: >95%
- **Boundary Condition Coverage**: >95%
- **TLB Translation Coverage**: >95%

## Build System

### Top-Level Targets

```bash
make help           # Show all available targets
make all           # Build everything
make clean         # Remove build artifacts
make distclean      # Deep clean including logs
```

### Component-Specific Targets

```bash
make rtl            # Compile RTL designs
make models        # Build SystemC/TLM models
make models-dpi    # Build DPI-enabled models
make verification  # Build UVM environment
make c_reference   # Build C reference model
```

### Simulation Targets

```bash
make sim-rtl       # Run RTL simulation
make sim-models    # Run SystemC models
make sim-uvm       # Run UVM verification
make sim-cosim     # Run co-simulation
```

## Configuration

### Memory Module Parameters

The RTL memory module is configurable:

```systemverilog
module memory #(
  parameter int VIRT_ADDR_WIDTH = 32,    // Virtual address width
  parameter int PHYS_ADDR_WIDTH = 28,    // Physical address width
  parameter int MEM_DEPTH = 16384,       // Memory depth in words
  parameter int PAGE_SIZE = 4096,        // Page size in bytes
  parameter int DATA_WIDTH = 64,         // Data word width
  parameter int PT_ENTRIES = 256         // TLB entries
) (
  // Clock and reset
  input  logic clk,
  input  logic rst_n,
  
  // Read/write/TLB interfaces...
);
```

### UVM Configuration

UVM test configuration via command line:

```bash
# Set test verbosity
make sim-uvm +UVM_VERBOSITY=UVM_HIGH

# Set random seed
make sim-uvm +UVM_TEST_SEED=12345

# Enable coverage collection
make sim-uvm +UVM_COVERAGE=1

# Set timeout
make sim-uvm +UVM_TIMEOUT_NS=10000000
```

## Debugging and Troubleshooting

### Common Issues

1. **SystemC Not Found**
   ```bash
   export SYSTEMC_HOME=/path/to/systemc
   ```

2. **DPI Compilation Errors**
   - Ensure SystemVerilog compiler supports DPI
   - Check that memory_dpi.c is compiled with compatible flags

3. **UVM Test Failures**
   - Check logs in `simulation/regression/logs/`
   - Verify DPI bridge initialization
   - Confirm RTL module compilation

### Debug Options

```bash
# Enable waveform generation
./scripts/run_regression.sh -w

# Enable DPI tracing
export UVM_DPI_TRACE=1

# Enable verbose UVM output
make sim-uvm +UVM_VERBOSITY=UVM_FULL
```

### Log Locations

- **Build Logs**: `build/` directory
- **Simulation Logs**: `simulation/` directory
- **Regression Reports**: `simulation/regression/`
- **Waveform Files**: `simulation/` (when enabled)

## Documentation

### API Documentation
```bash
make docs  # Generate Doxygen documentation
```

### Key Documentation Files
- `UVM_ML_ENVIRONMENT_COMPLETE.md` - UVM-ML integration details
- `models/tlm/README.md` - TLM architecture and usage
- `verification/uvm_ml/README.md` - UVM component descriptions

## Contributing

### Development Workflow

1. **Feature Branch**: Create branch for new features
2. **Unit Tests**: Add/update unit tests for changes
3. **Integration Tests**: Run full regression suite
4. **Documentation**: Update relevant documentation
5. **Code Review**: Submit pull request for review

### Testing Requirements

All changes must pass:
- Quick validation test: `./scripts/quick_test.sh`
- Full regression: `./scripts/run_regression.sh`
- Coverage goals: >95% functional coverage

## License

This project is provided as-is for educational and verification framework development purposes.

## Support

For questions or issues:

1. Check this README and documentation files
2. Run `./scripts/quick_test.sh` to verify setup
3. Examine build logs in `build/` directory
4. Review simulation logs in `simulation/` directory

---

**Status**: Production Ready - Complete End-to-End Verification Flow  
**Last Updated**: 2024  
**Maintained By**: Verification Team