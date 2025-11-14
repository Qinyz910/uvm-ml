# TLM Integration Architecture and UVM ML Connection Points

## Overview

This document describes the SystemC/TLM 2.0 verification environment, its integration with the UVM ML framework, and the planned connection to the RTL design via co-simulation.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Descriptions](#component-descriptions)
3. [Transaction Model](#transaction-model)
4. [UVM ML Integration](#uvm-ml-integration)
5. [RTL Co-simulation](#rtl-co-simulation)
6. [Integration Points](#integration-points)
7. [Usage Examples](#usage-examples)
8. [Future Enhancements](#future-enhancements)

## Architecture Overview

### Multi-Layer Verification Stack

```
┌─────────────────────────────────────────────────────────┐
│                    UVM ML Framework                      │
│  (SystemVerilog UVM components + SystemC TLM models)    │
├─────────────────────────────────────────────────────────┤
│  UVM ML Agents    │ UVM ML Testbench    │ UVM ML Env    │
├─────────────────────────────────────────────────────────┤
│                   TLM 2.0 Layer                          │
│  Initiators │ Targets │ Sockets │ Transactions           │
├─────────────────────────────────────────────────────────┤
│           Reference Model / RTL Co-simulation            │
│  C Reference   or   DPI-wrapped RTL                      │
├─────────────────────────────────────────────────────────┤
│                   RTL Design (Verilog)                   │
│           Memory subsystem with TLB                      │
└─────────────────────────────────────────────────────────┘
```

### Abstraction Levels

The verification environment supports three abstraction levels:

1. **Transaction Level (TLM)** - Current implementation
   - High-speed simulation
   - Suitable for functional verification
   - Uses C reference model
   - ~1000x faster than RTL simulation

2. **SystemVerilog RTL** - Future integration
   - Cycle-accurate
   - Enables detailed timing verification
   - Connected via DPI
   - ~10x slower than TLM

3. **Formal Verification** - Future enhancement
   - Property-based verification
   - Complete state space exploration
   - Complementary to simulation

## Component Descriptions

### 1. MemoryTransaction (tlm_transaction.h)

**Purpose**: Encapsulates memory-specific transaction attributes

**Design**:
- Extends TLM generic payload with custom attributes
- Maintains RTL interface semantics
- Supports all operation types: read, write, TLB load

**Key Fields**:
```cpp
enum OpType {
    OP_READ = 0x0,      // Corresponds to RTL MEM_READ
    OP_WRITE = 0x1,     // Corresponds to RTL MEM_WRITE
    OP_TLB_LOAD = 0x3   // Corresponds to RTL MEM_TLB_LD
};

// Response status codes (matching RTL)
enum StatusCode {
    STATUS_OK = 0x0,           // Successful
    STATUS_ERR_ADDR = 0x1,     // Translation error
    STATUS_ERR_ACCESS = 0x2,   // Access violation
    STATUS_ERR_WRITE = 0x3,    // Write error
    STATUS_PENDING = 0xF       // Pending/busy
};
```

**Mapping to RTL** (from rtl/include/memory_pkg.sv):
- Transaction attributes ↔ RTL request/response structures
- Byte mask ↔ RTL data_mask signal
- Virtual address ↔ RTL virt_addr signal
- Status codes ↔ RTL mem_status_e enum

### 2. MemoryInitiator (memory_transactor.h)

**Purpose**: TLM master that generates transactions

**Responsibilities**:
- Create transaction requests (read, write, TLB load)
- Send transactions via TLM socket
- Implement forward/backward transport interfaces
- Manage pending transaction queue

**Interface**:
```cpp
class MemoryInitiator : public sc_module {
public:
    tlm_utils::simple_initiator_socket<MemoryInitiator> socket;
    
    void send_read(uint64_t virt_addr, uint32_t byte_mask);
    void send_write(uint64_t virt_addr, uint32_t byte_mask, uint64_t data);
    void send_tlb_load(uint64_t virt_base, uint64_t phys_base);
};
```

**Usage in UVM ML**:
```cpp
// UVM ML sequence can call initiator methods
MemoryInitiator *initiator = /* get from factory */;
initiator->send_write(addr, mask, data);
```

### 3. MemoryTarget (memory_transactor.h)

**Purpose**: TLM slave that processes transactions

**Responsibilities**:
- Receive transactions via TLM socket
- Invoke reference model for operation
- Generate appropriate response
- Collect statistics

**Design**:
- Processes transactions synchronously
- Can be connected to reference model or RTL (via DPI)
- Maintains error counts and operation statistics

**Future RTL Connection**:
```cpp
class RTLMemoryTarget : public MemoryTarget {
    virtual void process_transaction(transaction_type &trans) {
        // Call RTL simulation via DPI
        uint64_t resp_status = dpi_memory_read(trans.address, trans.data);
        trans.response = resp_status;
    }
};
```

### 4. MemoryScoreboard (memory_scoreboard.h)

**Purpose**: Verification component for response validation

**Responsibilities**:
- Maintain shadow memory copy using reference model
- Compare actual responses with expected values
- Log mismatches and statistics
- Verify TLB state consistency

**Key Methods**:
```cpp
void submit_request(const MemoryTransaction &req);
void submit_response(const MemoryTransaction &resp);
unsigned int get_matches() const;
unsigned int get_mismatches() const;
void report_mismatches();
```

**Integration with UVM**:
- Can be driven by UVM ML monitor
- Reports results to UVM coverage database
- Provides hook for custom checks

### 5. MemoryMonitor (memory_transactor.h)

**Purpose**: Transaction observer for coverage and debugging

**Responsibilities**:
- Observe all transactions
- Collect coverage data
- Generate transaction traces
- Support debugging

**Statistics Collected**:
- Total transaction count
- Read/write/TLB load counts
- Operation frequency
- Access patterns

## Transaction Model

### Transaction Flow

```
UVM ML        TLM Initiator    TLM Socket    TLM Target    Reference
Sequence          (Master)                    (Slave)        Model
   │                  │              │           │              │
   │─ item ──────────>│              │           │              │
   │                  │─ BEGIN_REQ ─>│           │              │
   │                  │              │─ FW ────>│              │
   │                  │              │           │─ process ──>│
   │                  │              │           │<─ result ───│
   │                  │<─ END_RESP ──│           │              │
   │<─ rsp ────────────|              │           │              │
   │                  │              │           │              │
```

### Address Translation Sequence

```
Virtual Address Input
         │
         ▼
    ┌────────────┐
    │ Initiator  │ Creates transaction with virt_addr
    └─────┬──────┘
         │ send_read/write
         │
    ┌────▼──────┐
    │   Target  │ Processes request
    └─────┬──────┘
         │
    ┌────▼──────────────────────┐
    │ Reference Model / RTL      │
    │ - Translate virt→phys      │
    │ - Perform operation        │
    │ - Generate status          │
    └─────┬──────────────────────┘
         │
    ┌────▼──────────────┐
    │ Scoreboard        │ Verify response
    │ (shadow check)    │
    └──────────────────┘
```

### Byte Masking

Partial writes are supported through byte_mask field:

```
Byte:     │  7  │  6  │  5  │  4  │  3  │  2  │  1  │  0  │
Data:     │ 0x12│ 0x34│ 0x56│ 0x78│ 0x9A│ 0xBC│ 0xDE│ 0xF0│

Mask:     │  0  │  0  │  1  │  1  │  1  │  1  │  0  │  0  │
Result:   │  --  │  --  │0x56│ 0x78│ 0x9A│ 0xBC│  --  │  --  │
```

## UVM ML Integration

### UVM ML Transaction Format

The TLM MemoryTransaction directly corresponds to UVM transaction:

```systemverilog
// UVM SV side
class mem_transaction extends uvm_sequence_item;
    bit [63:0] address;
    bit [7:0] byte_mask;
    bit [63:0] data;
    mem_operation_t op_type;
    mem_status_t status;
endclass

// Maps to C++ MemoryTransaction
class MemoryTransaction {
    uint64_t virt_addr;       // → address
    uint32_t byte_mask;       // → byte_mask
    uint64_t data;            // → data
    OpType op_type;           // → op_type
    StatusCode status;        // → status
};
```

### UVM ML Agent Connection

**TLM Socket Binding**:

```cpp
// C++ side (SystemC)
MemoryInitiator initiator("initiator");
MemoryTarget target("target");
initiator.socket.bind(target.socket);

// Connect to UVM ML driver (SystemVerilog)
uvm_default_tree_printer().knobs.max_depth = -1;
assign uvm_ml_initiator_socket = initiator.socket;
assign uvm_ml_target_socket = target.socket;
```

**UVM ML Driver Implementation**:

```systemverilog
class mem_driver extends uvm_driver #(mem_transaction);
    `uvm_component_utils(mem_driver)
    
    uvm_tlm_if_base #(mem_transaction, mem_transaction) socket;
    
    virtual task run_phase(uvm_phase phase);
        mem_transaction trans;
        while (get_next_item(trans)) begin
            socket.put(trans);
            socket.get(trans);  // Get response
            item_done();
        end
    endtask
endclass
```

### UVM ML Environment Setup

```cpp
// Top-level connection
class uvm_ml_env : public uvm_environment {
    // SystemC/TLM components
    MemoryInitiator tlm_init;
    MemoryTarget tlm_target;
    MemoryScoreboard scoreboard;
    
    // UVM SV components (via UVM ML)
    mem_sequencer sequencer;
    mem_driver driver;
    mem_monitor monitor;
    
    // Binding
    connect_phase():
        driver.socket.bind(tlm_init.socket);
        tlm_init.socket.bind(tlm_target.socket);
        monitor.observe(tlm_target);
        scoreboard.observe(monitor);
};
```

## RTL Co-simulation

### DPI Bridge Architecture

For cycle-accurate verification with the RTL:

```
┌──────────────────────────────────┐
│     SystemVerilog Testbench      │
│  (UVM components, RTL instance)  │
├──────────────────────────────────┤
│         DPI Interface            │
├──────────────────────────────────┤
│  ┌──────────────────────────┐   │
│  │  DPI Wrapper (C/C++)     │   │
│  │  - xlate_memory_request  │   │
│  │  - xlate_memory_response │   │
│  └──────────────────────────┘   │
├──────────────────────────────────┤
│    SystemC/TLM Components        │
│  (RTLMemoryTarget, Scoreboard)   │
└──────────────────────────────────┘
```

### DPI Function Signatures

```cpp
// DPI functions for RTL communication
extern "C" {
    // Request: TLM → RTL
    void dpi_memory_request(uint64_t addr, uint32_t mask, uint64_t data, 
                           uint8_t op_type, uint32_t *transaction_id);
    
    // Response: RTL → TLM
    void dpi_memory_response(uint32_t transaction_id, uint8_t status,
                            uint64_t *read_data);
    
    // Clock tick
    void dpi_clock_tick();
};
```

### RTL Target Implementation

```cpp
class RTLMemoryTarget : public MemoryTarget {
    virtual void process_transaction(transaction_type &trans) {
        MemoryTransaction *mem_ext = nullptr;
        trans.get_extension(mem_ext);
        
        if (!mem_ext) return;
        
        // Call RTL via DPI
        uint32_t txn_id = next_transaction_id++;
        dpi_memory_request(mem_ext->virt_addr, mem_ext->byte_mask,
                          mem_ext->data, mem_ext->op_type, &txn_id);
        
        // Wait for RTL to respond
        uint64_t read_data = 0;
        uint8_t status = 0;
        dpi_memory_response(txn_id, &status, &read_data);
        
        mem_ext->status = (MemoryTransaction::StatusCode)status;
        mem_ext->data = read_data;
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
    }
};
```

### Co-simulation Test Environment

```cpp
class CoSimEnvironment : public sc_module {
    MemoryInitiator initiator;
    RTLMemoryTarget rtl_target;    // Connected to RTL via DPI
    MemoryScoreboard scoreboard;
    MemoryTestScenario test_scenario;
    
    void run_test() {
        // Tests run against RTL through DPI bridge
        // Results compared in scoreboard
        // Both TLM and RTL responses captured
    }
};
```

## Integration Points

### 1. Transaction Conversion (TLM ↔ RTL)

```
RTL Interface (from memory_pkg.sv)
├── Command: {READ, WRITE, FLUSH, TLB_LD}
├── Status: {OK, ERR_ADDR, ERR_ACCESS, ERR_WRITE, PENDING}
├── Signals: virt_addr, data, data_mask

TLM Extension (MemoryTransaction)
├── op_type: {OP_READ, OP_WRITE, OP_TLB_LOAD}
├── status: {STATUS_OK, STATUS_ERR_ADDR, ...}
├── Fields: virt_addr, data, byte_mask
```

### 2. Reference Model Integration

The C reference model (models/c_reference/) provides:
- Accurate memory behavior
- Virtual-to-physical translation
- TLB management
- Consistent responses for scoreboard

```cpp
// Usage in TLM components
memory_model_t *ref_model;
memory_model_create(&config, &ref_model);

// Process transaction
memory_model_read(ref_model, virt_addr, byte_mask, &data);
memory_model_write(ref_model, virt_addr, byte_mask, data);
memory_model_load_tlb(ref_model, virt_base, phys_base);
```

### 3. Testbench Integration

The testbench can be instantiated in both contexts:

**Standalone (C++ only)**:
```cpp
// Compile and run with reference model
MemoryTLMTestBench tb("tb");
sc_start();
```

**With UVM ML**:
```systemverilog
// VCS/Questa with UVM ML
import uvm_pkg::*;
import uvm_ml::*;

module tb;
    mem_env uvm_env;
    MemoryTLMTestBench tlm_bench;
    // Connect via UVM ML
endmodule
```

## Usage Examples

### Example 1: Simple Read/Write Test

```cpp
#include "memory_transactor.h"

int main() {
    // Create components
    MemoryInitiator init("init");
    MemoryTarget target("target");
    init.socket.bind(target.socket);
    
    // Create reference model
    memory_model_t *model;
    memory_model_create(nullptr, &model);
    target.set_memory_model(model);
    
    // Load TLB entry
    init.send_tlb_load(0x1000, 0x2000);
    wait(100, SC_NS);
    
    // Write data
    init.send_write(0x1000, 0xFF, 0x123456789ABCDEF0ULL);
    wait(100, SC_NS);
    
    // Read data back
    init.send_read(0x1000, 0xFF);
    wait(100, SC_NS);
    
    return 0;
}
```

### Example 2: With Scoreboard

```cpp
MemoryScoreboard scoreboard("sb");

// Submit request for tracking
MemoryTransaction req;
req.op_type = MemoryTransaction::OP_WRITE;
req.virt_addr = 0x1000;
req.byte_mask = 0xFF;
req.data = 0x1234567890ABCDEFULL;
scoreboard.submit_request(req);

// After DUT processes, submit response
MemoryTransaction resp;
resp.status = MemoryTransaction::STATUS_OK;
resp.data = req.data;
scoreboard.submit_response(resp);

// Check results
std::cout << "Matches: " << scoreboard.get_matches() << std::endl;
std::cout << "Mismatches: " << scoreboard.get_mismatches() << std::endl;
```

### Example 3: UVM ML Integration

```systemverilog
// UVM SV sequence
class memory_sequence extends uvm_sequence #(mem_transaction);
    `uvm_object_utils(memory_sequence)
    
    virtual task body();
        mem_transaction trans = mem_transaction::type_id::create("trans");
        
        // Generate transactions
        repeat(100) begin
            assert(trans.randomize());
            start_item(trans);
            finish_item(trans);
        end
    endtask
endclass
```

## Future Enhancements

### Phase 1: Current (TLM ↔ Reference Model)
- ✅ Transaction definitions
- ✅ Initiator/target components
- ✅ Scoreboard verification
- ✅ Test scenarios
- ✅ Documentation

### Phase 2: DPI Integration (TLM ↔ RTL)
- [ ] DPI bridge implementation
- [ ] RTL wrapper classes
- [ ] Cycle-accurate simulation
- [ ] Co-simulation testbench
- [ ] Synchronization mechanisms

### Phase 3: UVM ML Integration
- [ ] UVM ML sequence ports
- [ ] TLM socket registration
- [ ] UVM monitor/driver
- [ ] Multi-language sequences
- [ ] Coverage integration

### Phase 4: Advanced Features
- [ ] Pipelined transactions
- [ ] Burst operations
- [ ] Performance monitoring
- [ ] Formal verification hooks
- [ ] Power-aware verification

## References

### Documentation
- RTL Module: `rtl/include/memory_pkg.sv`
- Reference Model API: `models/c_reference/include/memory_model.h`
- TLM Components: `models/tlm/include/*.h`
- Test Scenario: `models/tlm/include/memory_test_scenario.h`

### Standards
- SystemC IEEE 1666-2011
- TLM 2.0 Specification (OSCI)
- UVM 1.2 Standard
- UVM ML 1.0 Reference Implementation

### Related Files
- SystemC Simulation: `models/tlm/src/tlm_testbench.cpp`
- Testbench Makefile: `models/tlm/Makefile`
- Build System: `Makefile` (top-level)

---

**Document Version**: 1.0  
**Status**: Production Ready  
**Last Updated**: 2024  
**Next Review**: After Phase 2 Implementation
