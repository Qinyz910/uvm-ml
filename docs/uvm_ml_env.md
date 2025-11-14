# UVM ML Memory Verification Environment

## Overview

This document describes the complete UVM ML-compatible verification environment for the memory subsystem with TLB (Translation Lookaside Buffer). The environment provides a comprehensive UVM-based verification framework that integrates with SystemC/TLM components and the C reference model for functional verification.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Descriptions](#component-descriptions)
3. [Sequence Library](#sequence-library)
4. [Test Suite](#test-suite)
5. [Scoreboard and Checking](#scoreboard-and-checking)
6. [Coverage Model](#coverage-model)
7. [Build and Run Instructions](#build-and-run-instructions)
8. [UVM ML Integration](#uvm-ml-integration)
9. [Debugging and Troubleshooting](#debugging-and-troubleshooting)

## Architecture Overview

### Verification Environment Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    UVM ML Environment                        │
├─────────────────────────────────────────────────────────────┤
│                        Tests                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Smoke   │  │  Stress  │  │   Edge   │  │   Base   │  │
│  │   Test   │  │   Test   │  │   Test   │  │   Test   │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     Environment                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  mem_env                                             │   │
│  │  ┌──────────────────┐    ┌──────────────────────┐  │   │
│  │  │   mem_agent      │    │   mem_scoreboard     │  │   │
│  │  │                  │───>│                      │  │   │
│  │  │  ┌────────────┐  │    │  - Shadow memory    │  │   │
│  │  │  │ Sequencer  │  │    │  - TLB tracking     │  │   │
│  │  │  └─────┬──────┘  │    │  - Data checking    │  │   │
│  │  │        │         │    │  - Error reporting  │  │   │
│  │  │  ┌─────▼──────┐  │    └──────────────────────┘  │   │
│  │  │  │  Driver    │  │                               │   │
│  │  │  └────────────┘  │    ┌──────────────────────┐  │   │
│  │  │                  │───>│   mem_coverage       │  │   │
│  │  │  ┌────────────┐  │    │                      │  │   │
│  │  │  │  Monitor   │  │    │  - Op coverage      │  │   │
│  │  │  └─────┬──────┘  │    │  - Status coverage  │  │   │
│  │  │        │         │    │  - Cross coverage   │  │   │
│  │  └────────┼─────────┘    └──────────────────────┘  │   │
│  └───────────┼──────────────────────────────────────────┘   │
├──────────────┼──────────────────────────────────────────────┤
│              │           Sequences                           │
│  ┌───────────▼────────────────────────────────────────────┐ │
│  │  Base │ Read │ Write │ TLB Load │ Smoke │ Stress │ Edge│ │
│  └────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                   Transaction Layer                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  mem_transaction (aligned with TLM MemoryTransaction) │ │
│  │  - op_type: READ, WRITE, TLB_LOAD                     │ │
│  │  - virt_addr, byte_mask, data                         │ │
│  │  - status: OK, ERR_ADDR, ERR_ACC, ERR_WRITE, PENDING  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │                                  │
         ▼                                  ▼
┌─────────────────────┐         ┌─────────────────────┐
│  TLM Layer          │         │  C Reference Model  │
│  (SystemC)          │◄───────►│  (Golden Model)     │
│  - Initiator        │         │  - Translation      │
│  - Target           │         │  - Memory ops       │
│  - Scoreboard       │         │  - TLB mgmt         │
└─────────────────────┘         └─────────────────────┘
```

### Design Philosophy

The environment follows these key principles:

1. **Separation of Concerns**: Clear boundaries between stimulus generation, DUT interface, checking, and coverage
2. **Reusability**: Modular components that can be reused in different test scenarios
3. **Configurability**: Flexible configuration object to adapt environment behavior
4. **Observability**: Comprehensive monitoring and reporting at all levels
5. **Integration**: Seamless connection with TLM/SystemC models via UVM ML

## Component Descriptions

### 1. Configuration Object (`mem_config`)

**File**: `verification/uvm_ml/agents/mem_agent/mem_config.svh`

The configuration object controls the behavior of the verification environment.

**Key Fields**:
```systemverilog
bit is_active          - Active/passive agent mode
bit has_coverage       - Enable functional coverage
bit has_scoreboard     - Enable scoreboard checking
int virt_addr_width    - Virtual address width (default: 64)
int phys_addr_width    - Physical address width (default: 64)
int page_size          - Page size in bytes (default: 4096)
int data_width         - Data width in bits (default: 64)
int mem_depth          - Memory depth (default: 1024)
int tlb_entries        - Number of TLB entries (default: 16)
```

**Usage**:
```systemverilog
mem_config cfg = mem_config::type_id::create("cfg");
cfg.is_active = UVM_ACTIVE;
cfg.has_coverage = 1;
cfg.tlb_entries = 8;
uvm_config_db#(mem_config)::set(null, "*", "cfg", cfg);
```

### 2. Transaction (`mem_transaction`)

**File**: `verification/uvm_ml/sequences/mem_transaction.svh`

The transaction class is fully aligned with the TLM `MemoryTransaction` extension.

**Key Fields**:
```systemverilog
rand mem_op_type_e op_type      - Operation: READ, WRITE, TLB_LOAD
rand bit [63:0]    virt_addr    - Virtual address
rand bit [7:0]     byte_mask    - Byte enable mask (8 bits for 64-bit data)
rand bit [63:0]    data         - Data value
rand bit [63:0]    tlb_virt_base - TLB virtual base (for TLB_LOAD)
rand bit [63:0]    tlb_phys_base - TLB physical base (for TLB_LOAD)
mem_status_e       status        - Response status
bit [63:0]         phys_addr     - Translated physical address
```

**Constraints**:
- Valid operation types
- Non-zero byte masks
- Reasonable address ranges (upper 16 bits zero)
- Page-aligned TLB bases (lower 12 bits zero)

**Mapping to TLM**:
The SystemVerilog `mem_transaction` maps directly to C++ `MemoryTransaction`:
```
SV mem_transaction          C++ MemoryTransaction
├── op_type              →  op_type
├── virt_addr            →  virt_addr
├── byte_mask            →  byte_mask
├── data                 →  data
├── status               →  status
├── tlb_virt_base        →  tlb_virt_base
└── tlb_phys_base        →  tlb_phys_base
```

### 3. Sequencer (`mem_sequencer`)

**File**: `verification/uvm_ml/agents/mem_agent/mem_sequencer.svh`

Standard UVM sequencer parameterized with `mem_transaction`.

**Features**:
- Manages sequence execution
- Arbitrates between multiple sequences
- Provides configuration access

### 4. Driver (`mem_driver`)

**File**: `verification/uvm_ml/agents/mem_agent/mem_driver.svh`

The driver translates sequence items into pin-level or TLM-level actions.

**Key Responsibilities**:
- Get transactions from sequencer
- Drive transactions to DUT/TLM interface
- Handle timing and protocol
- Broadcast driven transactions via analysis port

**Methods**:
```systemverilog
task drive_transaction(mem_transaction txn)   - Main drive logic
task drive_read(mem_transaction txn)          - Read operation
task drive_write(mem_transaction txn)         - Write operation
task drive_tlb_load(mem_transaction txn)      - TLB load operation
```

**UVM ML Integration Point**:
The driver is the primary integration point with TLM initiators. In UVM ML mode:
```systemverilog
// Driver calls TLM initiator via UVM ML bridge
ml_tlm::initiator_socket.put(txn);
```

### 5. Monitor (`mem_monitor`)

**File**: `verification/uvm_ml/agents/mem_agent/mem_monitor.svh`

Passively observes DUT/TLM activity and broadcasts transactions.

**Key Responsibilities**:
- Collect pin/interface activity
- Reconstruct transactions
- Broadcast via analysis port
- Maintain statistics

**Statistics Tracked**:
- Total transaction count
- Read/write/TLB load counts
- Transaction timestamps

### 6. Coverage Collector (`mem_coverage`)

**File**: `verification/uvm_ml/agents/mem_agent/mem_coverage.svh`

Implements functional coverage using SystemVerilog covergroups.

**Coverage Points**:
1. **Operation Type**: READ, WRITE, TLB_LOAD
2. **Status Codes**: OK, ERR_ADDR, ERR_ACC, ERR_WRITE, PENDING
3. **Byte Masks**: Full (0xFF), partial, empty
4. **Address Alignment**: Aligned vs unaligned
5. **Cross Coverage**: 
   - Operation × Status
   - Operation × Byte mask

**Coverage Goals**:
- 100% operation type coverage
- All status codes exercised
- Various byte mask patterns
- Aligned and unaligned accesses
- Cross combinations

### 7. Agent (`mem_agent`)

**File**: `verification/uvm_ml/agents/mem_agent/mem_agent.svh`

Container for sequencer, driver, monitor, and coverage collector.

**Configuration-Driven Instantiation**:
```systemverilog
if (cfg.is_active == UVM_ACTIVE)   - Create sequencer and driver
if (cfg.has_coverage)              - Create coverage collector
```

**Connections**:
- Driver ← Sequencer (sequence item port)
- Coverage ← Monitor (analysis port)
- Agent analysis port = Monitor analysis port

### 8. Scoreboard (`mem_scoreboard`)

**File**: `verification/uvm_ml/env/mem_scoreboard.svh`

The scoreboard implements golden model checking and result verification.

**Key Features**:

**Shadow Memory**:
```systemverilog
bit [63:0] shadow_memory [bit[63:0]];  // Sparse array
```
Maintains expected memory state based on write operations.

**TLB Tracking**:
```systemverilog
bit [63:0] tlb_map [bit[63:0]];        // Virtual → Physical mapping
```
Tracks TLB entries to perform address translation.

**Checking Functions**:

1. **Read Checking**:
   - Translate virtual → physical address
   - Compare read data with shadow memory
   - Verify status code

2. **Write Checking**:
   - Translate address
   - Update shadow memory with byte-masked data
   - Verify status OK

3. **TLB Load Checking**:
   - Update TLB map
   - Track active entry count
   - Verify status OK

**Statistics**:
- Match count (successful checks)
- Mismatch count (errors)
- Transaction count
- Active TLB entries

**Integration with C Reference Model**:
While this implementation uses a behavioral shadow model in SystemVerilog, the full UVM ML integration connects to the C reference model:

```systemverilog
// Future UVM ML integration
extern "C" void mem_model_read(uint64_t addr, uint64_t mask, uint64_t* data);
extern "C" void mem_model_write(uint64_t addr, uint64_t mask, uint64_t data);
```

### 9. Environment (`mem_env`)

**File**: `verification/uvm_ml/env/mem_env.svh`

Top-level environment container.

**Components**:
- `mem_agent`: Stimulus generation and monitoring
- `mem_scoreboard`: Result checking

**Build Phase**:
1. Get configuration
2. Create agent
3. Create scoreboard (if enabled)
4. Set configuration for sub-components

**Connect Phase**:
- Connect agent analysis port to scoreboard

**Report Phase**:
- Aggregate results
- Determine PASS/FAIL
- Print summary

## Sequence Library

### Base Sequence (`mem_base_sequence`)

**File**: `verification/uvm_ml/sequences/mem_base_sequence.svh`

Base class for all sequences with objection management.

**Features**:
- Automatic objection raise/drop
- Common utilities

### Read Sequence (`mem_read_sequence`)

**File**: `verification/uvm_ml/sequences/mem_read_sequence.svh`

Generates randomized read transactions.

**Parameters**:
```systemverilog
rand int unsigned num_reads = 10;
rand bit [63:0] start_addr = 64'h1000;
```

**Behavior**:
- Generate `num_reads` read operations
- Addresses in range [start_addr, start_addr + 4KB)
- Randomized byte masks

### Write Sequence (`mem_write_sequence`)

**File**: `verification/uvm_ml/sequences/mem_write_sequence.svh`

Generates randomized write transactions.

**Parameters**:
```systemverilog
rand int unsigned num_writes = 10;
rand bit [63:0] start_addr = 64'h1000;
```

**Behavior**:
- Generate `num_writes` write operations
- Addresses in range [start_addr, start_addr + 4KB)
- Randomized data and byte masks

### TLB Load Sequence (`mem_tlb_load_sequence`)

**File**: `verification/uvm_ml/sequences/mem_tlb_load_sequence.svh`

Configures TLB entries.

**Parameters**:
```systemverilog
rand int unsigned num_entries = 4;
rand bit [63:0] base_virt_addr = 64'h1000;
rand bit [63:0] base_phys_addr = 64'h10000;
```

**Behavior**:
- Load `num_entries` consecutive pages
- Virtual pages start at `base_virt_addr`
- Physical pages start at `base_phys_addr`
- All bases are page-aligned

### Smoke Sequence (`mem_smoke_sequence`)

**File**: `verification/uvm_ml/sequences/mem_smoke_sequence.svh`

Comprehensive smoke test combining all basic operations.

**Test Flow**:
1. Load 4 TLB entries (virt 0x1000-0x4000 → phys 0x10000-0x13000)
2. Write 10 transactions to mapped region
3. Read 10 transactions from mapped region

**Purpose**: Verify basic functionality of all operation types.

### Stress Sequence (`mem_stress_sequence`)

**File**: `verification/uvm_ml/sequences/mem_stress_sequence.svh`

High-volume random testing.

**Parameters**:
```systemverilog
rand int unsigned num_transactions = 1000;
rand bit [63:0] addr_range_start = 64'h1000;
rand bit [63:0] addr_range_end = 64'h10000;
```

**Test Flow**:
1. Calculate required TLB entries (up to 16)
2. Load TLB entries
3. Generate random read/write mix
4. Progress reporting every 100 transactions

**Purpose**: Stress the memory subsystem with high transaction volume.

### Edge Sequence (`mem_edge_sequence`)

**File**: `verification/uvm_ml/sequences/mem_edge_sequence.svh`

Exercises boundary and corner cases.

**Test Categories**:

1. **Partial Byte Masks**: 0x01, 0x03, 0x0F, 0x3F, 0x55, 0xAA, 0xF0
2. **Unaligned Addresses**: Offsets 1-7 from page boundaries
3. **Boundary Addresses**: 0x0, 0xFF8, 0x1000, 0xFFF8
4. **TLB Overflow**: Load 20 entries (exceeds typical capacity)
5. **Zero Patterns**: Write all zeros
6. **Max Patterns**: Write all ones (0xFFFFFFFFFFFFFFFF)

**Purpose**: Uncover edge case bugs and verify error handling.

## Test Suite

### Base Test (`base_test`)

**File**: `verification/uvm_ml/tests/base_test.sv`

Foundation for all tests.

**Features**:
- Environment creation
- Configuration setup
- Topology printing
- Basic reporting

**Methods**:
```systemverilog
virtual function void configure_test()  - Override for custom config
virtual task run_phase()                - Override for test body
```

### Smoke Test (`smoke_test`)

**File**: `verification/uvm_ml/tests/smoke_test.sv`

Quick functionality check.

**Run Command**:
```bash
make sim TEST=smoke_test
```

**Expected Duration**: ~100 transactions, <1 second

**Success Criteria**:
- All TLB loads succeed
- All writes complete successfully
- All reads return valid data
- No mismatches in scoreboard

### Stress Test (`stress_test`)

**File**: `verification/uvm_ml/tests/stress_test.sv`

High-volume testing.

**Run Command**:
```bash
make sim TEST=stress_test
```

**Expected Duration**: 1000 transactions, ~5-10 seconds

**Success Criteria**:
- All 1000 transactions complete
- No scoreboard mismatches
- Coverage goals met
- No memory leaks or hangs

### Edge Test (`edge_test`)

**File**: `verification/uvm_ml/tests/edge_test.sv`

Corner case verification.

**Run Command**:
```bash
make sim TEST=edge_test
```

**Expected Duration**: ~100 transactions, <2 seconds

**Success Criteria**:
- All edge cases handled correctly
- Error conditions properly reported
- No unexpected failures

## Scoreboard and Checking

### Checking Strategy

The scoreboard implements a **golden reference model** approach:

1. **Predict Expected Behavior**:
   - Maintain shadow memory
   - Track TLB state
   - Perform address translation

2. **Compare Actual vs Expected**:
   - Read data matches predicted value
   - Write operations succeed
   - Status codes are correct

3. **Report Mismatches**:
   - Log detailed error messages
   - Track mismatch count
   - Final PASS/FAIL determination

### Address Translation

```systemverilog
function bit translate_address(bit [63:0] virt_addr, output bit [63:0] phys_addr);
  bit [63:0] page_base = {virt_addr[63:12], 12'h0};
  bit [11:0] page_offset = virt_addr[11:0];
  
  if (tlb_map.exists(page_base)) begin
    phys_addr = tlb_map[page_base] + page_offset;
    return 1;  // Translation successful
  end
  return 0;    // Translation failed
endfunction
```

### Byte Masking

```systemverilog
function bit [63:0] apply_byte_mask(bit [63:0] data, bit [7:0] mask);
  bit [63:0] result = 0;
  for (int i = 0; i < 8; i++) begin
    if (mask[i]) result[i*8 +: 8] = data[i*8 +: 8];
  end
  return result;
endfunction
```

### Shadow Memory Update

```systemverilog
function void update_shadow_memory(bit [63:0] addr, bit [63:0] data, bit [7:0] mask);
  bit [63:0] old_data = shadow_memory.exists(addr) ? shadow_memory[addr] : 0;
  for (int i = 0; i < 8; i++) begin
    if (mask[i]) old_data[i*8 +: 8] = data[i*8 +: 8];
  end
  shadow_memory[addr] = old_data;
endfunction
```

## Coverage Model

### Functional Coverage Goals

1. **Operation Coverage**: 100%
   - All operation types exercised

2. **Status Coverage**: >90%
   - Focus on common statuses (OK, ERR_ADDR)
   - Error statuses may be infrequent

3. **Data Pattern Coverage**: >80%
   - Various byte masks
   - Aligned and unaligned addresses

4. **Cross Coverage**: >70%
   - Operation × Status combinations
   - Operation × Byte mask patterns

### Coverage Analysis

View coverage report:
```bash
# VCS
urg -dir simv.vdb -report coverage_report
firefox urgReport/dashboard.html

# Questa
coverage report -html -output cov_html
firefox cov_html/index.html
```

### Coverage Closure Strategy

1. Review uncovered bins
2. Identify missing scenarios
3. Add directed tests or constraints
4. Re-run and verify closure

## Build and Run Instructions

### Prerequisites

**Required Tools**:
- SystemVerilog simulator with UVM 1.2 support:
  - Synopsys VCS 2018.09 or later
  - Mentor Questa 10.7 or later
  - Cadence Xcelium 19.09 or later
- GNU Make 4.0+

**Optional Tools**:
- UVM ML framework (for full TLM integration)
- SystemC 2.3.3 (for TLM co-simulation)
- C compiler for reference model

### Directory Structure

```
verification/uvm_ml/
├── Makefile                    # Top-level build file
├── agents/
│   └── mem_agent/
│       ├── mem_agent_pkg.sv
│       ├── mem_config.svh
│       ├── mem_sequencer.svh
│       ├── mem_driver.svh
│       ├── mem_monitor.svh
│       ├── mem_coverage.svh
│       └── mem_agent.svh
├── sequences/
│   ├── mem_sequences_pkg.sv
│   ├── mem_transaction.svh
│   ├── mem_base_sequence.svh
│   ├── mem_read_sequence.svh
│   ├── mem_write_sequence.svh
│   ├── mem_tlb_load_sequence.svh
│   ├── mem_smoke_sequence.svh
│   ├── mem_stress_sequence.svh
│   └── mem_edge_sequence.svh
├── env/
│   ├── mem_env_pkg.sv
│   ├── mem_scoreboard.svh
│   └── mem_env.svh
├── tests/
│   ├── mem_tests_pkg.sv
│   ├── base_test.sv
│   ├── smoke_test.sv
│   ├── stress_test.sv
│   └── edge_test.sv
└── tb/
    └── testbench_top.sv
```

### Quick Start

**1. Run smoke test (default)**:
```bash
cd verification/uvm_ml
make sim
```

**2. Run specific test**:
```bash
make sim TEST=smoke_test
make sim TEST=stress_test
make sim TEST=edge_test
```

**3. Change simulator**:
```bash
make sim SIM=vcs TEST=smoke_test
make sim SIM=questa TEST=stress_test
make sim SIM=xcelium TEST=edge_test
```

**4. Adjust verbosity**:
```bash
make sim TEST=smoke_test VERBOSITY=UVM_LOW
make sim TEST=smoke_test VERBOSITY=UVM_HIGH
make sim TEST=smoke_test VERBOSITY=UVM_DEBUG
```

**5. Clean build artifacts**:
```bash
make clean
```

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make all` | Compile and run default test |
| `make sim` | Compile and simulate |
| `make compile` | Compile only |
| `make run` | Run simulation (after compile) |
| `make smoke` | Run smoke test |
| `make stress` | Run stress test |
| `make edge` | Run edge test |
| `make clean` | Remove build artifacts |
| `make config` | Display configuration |
| `make help` | Show help message |

### Simulation Logs

**Compile log**: `compile.log`
**Simulation log**: `sim_<test_name>.log`

Example:
```bash
tail -f sim_smoke_test.log
```

### Expected Output

Successful smoke test output:
```
UVM_INFO @ 0: reporter [RNTST] Running test smoke_test...
UVM_INFO @ 0: uvm_test_top [SMOKE_TEST] === Starting Smoke Test ===
UVM_INFO @ 0: uvm_test_top.env.agent.sequencer@@smoke_seq [MEM_SMOKE] === Starting Smoke Test Sequence ===
UVM_INFO @ 0: uvm_test_top.env.agent.sequencer@@smoke_seq [MEM_SMOKE] Step 1: Loading TLB entries
UVM_INFO @ 0: uvm_test_top.env.scoreboard [MEM_SB] TLB Load: virt=0x1000 -> phys=0x10000 (entries=1)
...
UVM_INFO @ 100ns: uvm_test_top [SMOKE_TEST] === Smoke Test Finished ===
UVM_INFO @ 100ns: uvm_test_top.env.scoreboard [MEM_SB] === Scoreboard Final Report ===
UVM_INFO @ 100ns: uvm_test_top.env.scoreboard [MEM_SB] Total transactions: 24
UVM_INFO @ 100ns: uvm_test_top.env.scoreboard [MEM_SB] Matches:            24
UVM_INFO @ 100ns: uvm_test_top.env.scoreboard [MEM_SB] Mismatches:         0
UVM_INFO @ 100ns: uvm_test_top.env.scoreboard [MEM_SB] Test PASSED: All transactions matched!
UVM_INFO @ 100ns: reporter [TEST_PASS] Test passed!
```

## UVM ML Integration

### Overview

UVM ML (Multi-Language) enables seamless integration between:
- **SystemVerilog UVM** verification components
- **SystemC TLM** transaction-level models
- **C/C++** reference models

### Integration Architecture

```
┌─────────────────────────────────────────────────────┐
│             UVM ML Framework                         │
├─────────────────────────────────────────────────────┤
│  SystemVerilog (UVM)     │  SystemC (TLM)           │
│  ┌──────────────────┐    │  ┌──────────────────┐   │
│  │  mem_driver      │───────>│ MemoryInitiator  │   │
│  │  (Producer)      │    │  │ (TLM Socket)     │   │
│  └──────────────────┘    │  └──────────────────┘   │
│                          │           │              │
│  ┌──────────────────┐    │  ┌────────▼─────────┐   │
│  │  mem_monitor     │<──────│  MemoryTarget    │   │
│  │  (Consumer)      │    │  │  (TLM Socket)    │   │
│  └──────────────────┘    │  └──────────────────┘   │
│                          │           │              │
│  ┌──────────────────┐    │  ┌────────▼─────────┐   │
│  │  mem_scoreboard  │<──────│  C Ref Model     │   │
│  └──────────────────┘    │  └──────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### TLM Socket Binding

**C++ Side (SystemC)**:
```cpp
// In top-level sc_main or module
MemoryInitiator initiator("initiator");
MemoryTarget target("target");

// Bind TLM sockets
initiator.socket.bind(target.socket);

// Register with UVM ML
ml_tlm::external_if<mem_transaction>* uvm_if = 
    new ml_tlm::external_if<mem_transaction>("uvm_sv_to_sc", &initiator.socket);
```

**SystemVerilog Side**:
```systemverilog
// In mem_driver
ml_tlm_initiator_socket #(mem_transaction) tlm_socket;

function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  tlm_socket = ml_tlm_initiator_socket#(mem_transaction)::type_id::create("tlm_socket", this);
  tlm_socket.connect("uvm_sv_to_sc");
endfunction

task drive_transaction(mem_transaction txn);
  tlm_socket.put(txn);  // Sends to SystemC TLM socket
endtask
```

### Transaction Conversion

UVM ML automatically converts between SystemVerilog and C++ representations:

**SystemVerilog → C++**:
```systemverilog
mem_transaction sv_txn;
sv_txn.op_type = MEM_READ;
sv_txn.virt_addr = 64'h1000;
tlm_socket.put(sv_txn);  // Converted to MemoryTransaction
```

**C++ → SystemVerilog**:
```cpp
MemoryTransaction cpp_txn;
cpp_txn.op_type = MemoryTransaction::OP_READ;
cpp_txn.virt_addr = 0x1000;
socket.put(cpp_txn);  // Observed by mem_monitor
```

### Building with UVM ML

**Compilation**:
```bash
# Compile SystemC TLM components
make -C ../../models/tlm

# Compile UVM ML adapter
uvmc compile -lang systemc -sc uvm_ml_adapter.cpp

# Compile SystemVerilog with UVM ML
vcs -sverilog +incdir+$UVM_ML_HOME/sv \
    -ntb_opts uvm-1.2 \
    $UVM_ML_HOME/sv/uvm_ml_adapter.sv \
    testbench_top.sv
```

**Simulation**:
```bash
./simv +UVM_TESTNAME=smoke_test
```

### Reference Model Integration

The scoreboard can be enhanced to call the C reference model directly:

```systemverilog
// Import DPI-C functions
import "DPI-C" function void mem_model_create(output longint model_handle);
import "DPI-C" function int mem_model_read(longint model, longint addr, int mask, output longint data);
import "DPI-C" function int mem_model_write(longint model, longint addr, int mask, longint data);
import "DPI-C" function int mem_model_load_tlb(longint model, longint virt_base, longint phys_base);

// In mem_scoreboard
longint ref_model_handle;

function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  mem_model_create(ref_model_handle);
endfunction

function void check_read_transaction(mem_transaction txn);
  longint expected_data;
  int status;
  status = mem_model_read(ref_model_handle, txn.virt_addr, txn.byte_mask, expected_data);
  if (txn.data != expected_data) begin
    `uvm_error("MISMATCH", $sformatf("Expected 0x%0h, got 0x%0h", expected_data, txn.data))
  end
endfunction
```

### Future Enhancements

1. **Full UVM ML Adapter**: Complete adapter for driver/monitor
2. **DPI Integration**: Direct calls to C reference model
3. **RTL Co-simulation**: Connect to Verilog DUT via TLM→DPI bridge
4. **Performance Analysis**: Transaction timing and throughput metrics

## Debugging and Troubleshooting

### Common Issues

**1. Compilation Errors**

*Error*: `Package 'mem_sequences_pkg' not found`
*Solution*: Check include paths in Makefile, ensure all packages compiled in order

*Error*: `Constraint expression not constant`
*Solution*: Verify constraint syntax, check for typos in field names

**2. Runtime Errors**

*Error*: `Fatal: Null object access`
*Solution*: Check configuration database settings, ensure all components created

*Error*: `Timeout: Simulation exceeds 1ms`
*Solution*: Increase timeout or check for sequence deadlock

**3. Scoreboard Mismatches**

*Error*: `Read MISMATCH: expected 0x1234, got 0x5678`
*Solution*:
- Verify write sequence executed before read
- Check TLB entries loaded correctly
- Review address translation logic

**4. Coverage Gaps**

*Issue*: Coverage not reaching goals
*Solution*:
- Run `coverage report -details` to identify uncovered bins
- Add directed tests for missing scenarios
- Adjust sequence constraints to hit corners

### Debug Features

**1. Transaction Logging**

Increase verbosity:
```bash
make sim TEST=smoke_test VERBOSITY=UVM_HIGH
```

**2. Waveform Dumping**

Add to test:
```systemverilog
initial begin
  $dumpfile("waves.vcd");
  $dumpvars(0, testbench_top);
end
```

**3. Scoreboard Tracing**

Enable detailed checking:
```systemverilog
scoreboard.set_report_verbosity_level(UVM_DEBUG);
```

**4. Sequence Tracing**

```systemverilog
seq.set_starting_phase(phase);
uvm_config_db#(int)::set(null, "*", "recording_detail", UVM_FULL);
```

### Performance Tips

1. **Reduce Verbosity**: Use UVM_LOW for regression runs
2. **Disable Coverage**: Set `has_coverage = 0` for fast debug
3. **Smaller Tests**: Use base_test for quick syntax checks
4. **Parallel Runs**: Run multiple tests in parallel

### Support and Contact

For issues or questions:
- Check documentation in `docs/` directory
- Review TLM integration guide: `docs/tlm_integration.md`
- Consult C reference model docs: `docs/c_reference.md`

## Appendix

### Quick Reference Card

```systemverilog
// Create transaction
mem_transaction txn = mem_transaction::type_id::create("txn");
assert(txn.randomize() with { op_type == MEM_READ; });

// Start sequence
mem_smoke_sequence seq = mem_smoke_sequence::type_id::create("seq");
seq.start(sequencer);

// Configure environment
mem_config cfg = mem_config::type_id::create("cfg");
cfg.tlb_entries = 8;
uvm_config_db#(mem_config)::set(null, "*", "cfg", cfg);

// Run test
make sim TEST=smoke_test VERBOSITY=UVM_MEDIUM
```

### Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| mem_config.svh | ~40 | Configuration object |
| mem_transaction.svh | ~110 | Transaction definition |
| mem_sequencer.svh | ~20 | Sequencer |
| mem_driver.svh | ~80 | Driver |
| mem_monitor.svh | ~75 | Monitor |
| mem_coverage.svh | ~80 | Coverage |
| mem_agent.svh | ~60 | Agent container |
| mem_scoreboard.svh | ~185 | Checking logic |
| mem_env.svh | ~55 | Environment |
| mem_*_sequence.svh | ~300 | Sequence library |
| *_test.sv | ~100 | Test suite |
| testbench_top.sv | ~25 | Testbench top |
| **Total** | **~1130** | **Complete UVM env** |

### Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2024 | AI Assistant | Initial UVM ML environment implementation |

---

*End of UVM ML Memory Verification Environment Documentation*
