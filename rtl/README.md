# RTL (Register-Transfer Level) Directory

This directory contains all RTL design files and related components.

## Structure
```
rtl/
├── src/                  # RTL source files (.sv, .v)
│   └── memory.sv         # Memory module with virtual-to-physical translation
├── include/              # Header files, packages, and interfaces
│   ├── common_pkg.sv     # Common definitions and parameters
│   └── memory_pkg.sv     # Memory module package definitions
├── tb/                   # Testbench components
│   └── memory_tb.sv      # Memory module testbench
├── run_memory_tb.sh      # Script to compile and run testbench
└── README.md             # This file
```

## Implemented Components

### Memory Module (memory.sv)

A configurable memory subsystem with virtual-to-physical address translation using a page table-based translation lookaside buffer (TLB).

**Features:**
- Virtual-to-physical address translation with TLB
- Configurable virtual/physical address widths
- Parameterizable memory depth and page size
- Read/write channels with handshake protocols
- TLB load interface for runtime configuration
- Byte-masked write operations
- Status/error reporting

**Parameters:**
- `VIRT_ADDR_WIDTH`: Virtual address width (default: 32 bits)
- `PHYS_ADDR_WIDTH`: Physical address width (default: 28 bits)
- `MEM_DEPTH`: Memory depth in words (default: 16384)
- `PAGE_SIZE`: Page size in bytes (default: 4096)
- `DATA_WIDTH`: Data word width (default: 64 bits)
- `PT_ENTRIES`: Maximum TLB entries (default: 256)

**Testbench (memory_tb.sv):**
- Tests TLB load operations
- Tests read/write with translation hits
- Tests translation miss error handling
- Tests partial (masked) write operations
- Tests sequential read/write sequences

**Running the Testbench:**
```bash
cd rtl
./run_memory_tb.sh
```

**Documentation:**
See `docs/rtl_memory.md` for detailed module documentation including:
- Architecture overview
- Interface specifications
- Timing diagrams
- Address translation details
- Configuration register descriptions
- Usage examples

## Guidelines
- Use SystemVerilog for new designs
- Follow naming conventions: lowercase with underscores for signals
- Include appropriate comments and documentation
- Use packages for shared definitions and utilities

## File Naming
- Module files: `<module_name>.sv`
- Package files: `<package_name>_pkg.sv`
- Interface files: `<interface_name>_if.sv`
- Testbench files: `<dut>_tb.sv`

## Compilation

### Using Verilator (Recommended)
```bash
verilator --lint-only --timing rtl/src/memory.sv rtl/tb/memory_tb.sv
```

### Using VCS
```bash
vcs -sverilog +v2k -timescale=1ns/1ps rtl/src/memory.sv rtl/tb/memory_tb.sv
```

### Using Questa/ModelSim
```bash
vlog -sv rtl/src/memory.sv rtl/tb/memory_tb.sv
vsim -c work.memory_tb -do "run -all; quit"
```

## Completed Tasks
- [x] Add RTL source files (Memory module)
- [x] Create package definitions (memory_pkg.sv)
- [x] Implement testbench components (memory_tb.sv)
- [x] Document module interface and behavior
- [x] Verify compilation with SystemVerilog compiler

## Future Enhancements
- [ ] Multi-level page tables
- [ ] LRU TLB replacement policy
- [ ] TLB flush/invalidate operations
- [ ] Memory protection attributes
- [ ] Performance monitoring counters
