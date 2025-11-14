# Memory RTL Module Documentation

## Overview

The Memory RTL module (`memory.sv`) is a configurable memory subsystem that implements virtual-to-physical address translation with a page table-based translation lookaside buffer (TLB). This module provides a high-level memory interface suitable for RTL-level system verification.

## Architecture

### Block Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Memory Module                        │
│                                                         │
│  ┌─────────────┐        ┌──────────────────────────┐  │
│  │  Read Req   │───────▶│  Address Translation     │  │
│  │  Channel    │        │  (TLB Lookup)            │  │
│  └─────────────┘        └──────────┬───────────────┘  │
│                                    │                   │
│  ┌─────────────┐        ┌──────────▼───────────────┐  │
│  │ Write Req   │───────▶│  Memory Array            │  │
│  │  Channel    │        │  (Data Storage)          │  │
│  └─────────────┘        └──────────┬───────────────┘  │
│                                    │                   │
│  ┌─────────────┐        ┌──────────▼───────────────┐  │
│  │  TLB Load   │───────▶│  Translation Table       │  │
│  │  Interface  │        │  (Page Table)            │  │
│  └─────────────┘        └──────────────────────────┘  │
│                                    │                   │
│                         ┌──────────▼───────────────┐  │
│                         │  Read/Write Response     │  │
│                         │  Channel                 │  │
│                         └──────────────────────────┘  │
│                                                       │
└─────────────────────────────────────────────────────────┘
```

## Interface Definition

### Ports

#### Clock and Reset
- **clk** (input): System clock
- **rst_n** (input): Active-low asynchronous reset

#### Read Request Channel (Master Request)
- **read_req_valid** (input): Read request valid signal
- **read_req_addr[VIRT_ADDR_WIDTH-1:0]** (input): Virtual read address
- **read_req_mask[(DATA_WIDTH/8)-1:0]** (input): Read byte mask
- **read_req_ready** (output): Module ready to accept read requests

#### Read Response Channel (Slave Response)
- **read_resp_valid** (output): Read response valid signal
- **read_resp_data[DATA_WIDTH-1:0]** (output): Read data
- **read_resp_status[3:0]** (output): Response status code
- **read_resp_ready** (input): External entity ready to accept responses

#### Write Request Channel (Master Request)
- **write_req_valid** (input): Write request valid signal
- **write_req_addr[VIRT_ADDR_WIDTH-1:0]** (input): Virtual write address
- **write_req_mask[(DATA_WIDTH/8)-1:0]** (input): Write byte mask
- **write_req_data[DATA_WIDTH-1:0]** (input): Write data
- **write_req_ready** (output): Module ready to accept write requests

#### Write Response Channel (Slave Response)
- **write_resp_valid** (output): Write response valid signal
- **write_resp_status[3:0]** (output): Response status code
- **write_resp_ready** (input): External entity ready to accept responses

#### TLB Management Interface
- **tlb_load_valid** (input): TLB entry load request valid
- **tlb_load_virt_base[VIRT_ADDR_WIDTH-1:0]** (input): Virtual page base address for TLB entry
- **tlb_load_phys_base[PHYS_ADDR_WIDTH-1:0]** (input): Physical page base address for TLB entry
- **tlb_load_ready** (output): Module ready to accept TLB load requests

#### Status/Control Signals
- **tlb_num_entries[$clog2(PT_ENTRIES)-1:0]** (output): Number of valid TLB entries

## Configurable Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| VIRT_ADDR_WIDTH | 32 | Virtual address bit width |
| PHYS_ADDR_WIDTH | 28 | Physical address bit width |
| MEM_DEPTH | 16384 | Number of words in memory array |
| PAGE_SIZE | 4096 | Page size in bytes (must be power of 2) |
| DATA_WIDTH | 64 | Data word width in bits |
| PT_ENTRIES | 256 | Maximum number of TLB entries |

## Response Status Codes

| Code | Value | Description |
|------|-------|-------------|
| MEM_OK | 0x0 | Transaction completed successfully |
| MEM_ERR_ADDR | 0x1 | Address translation error (TLB miss) |
| MEM_ERR_ACCESS | 0x2 | Access violation (physical address out of bounds) |
| MEM_ERR_WRITE | 0x3 | Write error |
| MEM_PENDING | 0xF | Operation pending/busy |

## Address Translation

### Translation Process

The Memory module translates virtual addresses to physical addresses using a simple page table mechanism:

1. **Virtual Address Format**:
   ```
   [31:12] Virtual Page Number (20 bits for default 32-bit VIRT_ADDR_WIDTH)
   [11:0]  Page Offset (12 bits for default PAGE_SIZE=4096)
   ```

2. **Physical Address Format**:
   ```
   [27:12] Physical Page Number (16 bits for default 28-bit PHYS_ADDR_WIDTH)
   [11:0]  Page Offset (same as virtual address offset)
   ```

3. **TLB Lookup**:
   - Virtual page number is compared with all TLB entries
   - On hit: Physical page number from matching entry is used
   - On miss: MEM_ERR_ADDR status is returned

### Translation Table (TLB)

The TLB is implemented as a fully-associative page table with the following structure:

```
TLB Entry:
├── valid: 1 bit
├── virt_base: VIRT_PAGE_BITS
└── phys_base: PHYS_PAGE_BITS
```

**Capacity**: Configurable from 1 to 256 entries (PT_ENTRIES parameter)
**Replacement Policy**: Simple round-robin write pointer (new entries overwrite oldest)

## Operating Modes

### 1. Read Operation

```
Cycle 1: read_req_valid=1, read_req_addr=<virt_addr>
         ↓ (translation lookup begins)
Cycle 2: read_resp_valid=1, read_resp_data=<data>, read_resp_status=<status>
```

**Operation**:
- Request phase: Master sets read_req_valid with virtual address and byte mask
- Translation phase: Module performs TLB lookup
- Response phase: Module returns read data and status code

### 2. Write Operation

```
Cycle 1: write_req_valid=1, write_req_addr=<virt_addr>, write_req_data=<data>
         ↓ (translation lookup begins)
Cycle 2: write_resp_valid=1, write_resp_status=<status>
```

**Operation**:
- Request phase: Master sets write_req_valid with virtual address, data, and byte mask
- Translation phase: Module performs TLB lookup
- Write phase: Module writes data to translated physical address (masked)
- Response phase: Module returns status code

### 3. TLB Load Operation

```
Cycle 1: tlb_load_valid=1, tlb_load_virt_base=<vpage>, tlb_load_phys_base=<ppage>
         ↓ (TLB entry is programmed)
Cycle 2: Next entry can be loaded or normal read/write operations resume
```

**Operation**:
- Load request: Master provides virtual and physical page base addresses
- Entry storage: Module stores entry in next available TLB slot
- Pointer update: Write pointer increments to next slot

## Timing Diagrams

### Read Operation Timing

```
clk         ─╮─╯─╮─╯─╮─╯─╮─╯─
rst_n       ───╮───────────────
read_req_valid ──╮───────╭────
read_req_addr   ──<addr>─────
read_resp_valid ─────╮────────
read_resp_data  ─────<data>───
read_resp_status ─────<status>─
```

### Write Operation Timing

```
clk           ─╮─╯─╮─╯─╮─╯─╮─╯─
rst_n         ───╮───────────────
write_req_valid ──╮───────╭────
write_req_addr   ──<addr>─────
write_req_data   ──<data>─────
write_req_mask   ──<mask>─────
write_resp_valid ─────╮────────
write_resp_status ─────<status>─
```

### TLB Load Timing

```
clk               ─╮─╯─╮─╯─╮─╯─╮─╯─╮─╯─
rst_n             ───╮───────────────────
tlb_load_valid     ──╮───╮───╮───────────
tlb_load_virt_base  ──<v0>─<v1>─<v2>─────
tlb_load_phys_base  ──<p0>─<p1>─<p2>─────
tlb_num_entries     ───1───2───3─────────
```

## Configuration Registers

The Memory module is entirely parameterizable. Configuration is set at compile/elaboration time:

### Parameter Configuration Example

```systemverilog
// Instantiate with custom configuration
memory #(
  .VIRT_ADDR_WIDTH(32),
  .PHYS_ADDR_WIDTH(28),
  .MEM_DEPTH(16384),
  .PAGE_SIZE(4096),
  .DATA_WIDTH(64),
  .PT_ENTRIES(256)
) mem_inst (
  // port connections
);
```

### Runtime TLB Configuration

TLB entries are programmed at runtime using the TLB Load interface:

```systemverilog
// Program TLB entry for virtual page 0x1 -> physical page 0x8
tlb_load_valid = 1'b1;
tlb_load_virt_base = 32'h00001000;  // Virtual page base
tlb_load_phys_base = 28'h0008000;   // Physical page base
@(posedge clk);
tlb_load_valid = 1'b0;
```

## Usage Example

### Basic Read-Write Sequence

```systemverilog
// 1. Program TLB entries during initialization
tlb_load_valid = 1'b1;
tlb_load_virt_base = 32'h00000000;
tlb_load_phys_base = 28'h0000000;
@(posedge clk);
tlb_load_valid = 1'b0;

// 2. Perform write operation
write_req_valid = 1'b1;
write_req_addr = 32'h00000100;
write_req_data = 64'hDEADBEEF_CAFEBABE;
write_req_mask = 8'hFF;
@(posedge clk);
write_req_valid = 1'b0;

// 3. Wait for write response
wait(write_resp_valid == 1'b1);
if (write_resp_status == MEM_OK) begin
  $display("Write successful");
end
@(posedge clk);

// 4. Perform read operation
read_req_valid = 1'b1;
read_req_addr = 32'h00000100;
read_req_mask = 8'hFF;
@(posedge clk);
read_req_valid = 1'b0;

// 5. Wait for read response
wait(read_resp_valid == 1'b1);
if (read_resp_status == MEM_OK) begin
  $display("Read data: 0x%h", read_resp_data);
end
```

## Address Translation Assumptions

1. **Page Alignment**: All virtual and physical addresses must be page-aligned (lower PAGE_SIZE bits are offset, not translated)

2. **Page Size**: Must be a power of 2 (4096, 8192, etc.)

3. **Single-Entry TLB Replacement**: When TLB is full, new entries overwrite oldest entries using a round-robin pointer

4. **Fully Associative TLB**: All TLB entries can match any virtual address

5. **Immediate Translation**: Address translation happens within the same cycle as request

6. **No Hierarchical Tables**: Page table is flat, single-level structure

## Error Handling

### Translation Miss (MEM_ERR_ADDR)
- Occurs when virtual page is not found in TLB
- Returns MEM_ERR_ADDR status without accessing memory
- Read data returned is zero

### Access Violation (MEM_ERR_ACCESS)
- Occurs when translated physical address exceeds MEM_DEPTH
- Returns MEM_ERR_ACCESS status
- No memory access is performed

### Valid Indicator
All TLB entries must have valid flag set to one to participate in translation

## Synthesis Considerations

- **Memory Array**: Uses inferred RAM (behavioral HDL)
- **TLB Array**: Uses inferred small RAM or registers depending on synthesis tool
- **Multiplexer**: Fully associative lookup requires wide multiplexer
- **Area Scaling**: Grows with PT_ENTRIES parameter (linear with TLB depth)

### Estimated Resource Usage (28nm Technology)

| Configuration | RAM (bytes) | LUTs | Registers |
|---|---|---|---|
| 16KB MEM, 256 TLB | ~17KB | ~3K | ~2K |
| 64KB MEM, 512 TLB | ~65KB | ~5K | ~4K |

## Simulation and Testing

### Testbench Features

The provided testbench (`memory_tb.sv`) includes:

1. **TLB Load Tests**: Verify TLB entry programming
2. **Write-Read Tests**: Test write followed by read verification
3. **Translation Hit Tests**: Verify correct data retrieval
4. **Translation Miss Tests**: Verify error handling
5. **Partial Write Tests**: Test masked write operations
6. **Sequential Access Tests**: Test multiple consecutive operations

### Running Simulations

```bash
# Compile and run with VCS
vcs -sverilog -timescale=1ns/1ps \
    rtl/include/*.sv \
    rtl/src/memory.sv \
    rtl/tb/memory_tb.sv \
    -o build/memory_sim

# Run simulation
./build/memory_sim

# Run with Questa
vlog -sv rtl/include/*.sv rtl/src/memory.sv rtl/tb/memory_tb.sv
vsim -c work.memory_tb -do "run -all; quit"
```

### Expected Output

```
===== Memory Module Testbench Starting =====

[TEST 1] Testing TLB Load Operations
  Test 1.1 PASS: Loaded virtual page 0x00000 -> physical page 0x00000
  Test 1.2 PASS: Loaded virtual page 0x1 -> physical page 0x8
  Test 1.3 PASS: Loaded virtual page 0x2 -> physical page 0x10
  Test 1: 3 subtests PASSED

[TEST 2] Testing Write Operations with Translation Hits
  Test 2.1 PASS: Wrote data to virtual address 0x00000100
  Test 2.2 PASS: Wrote data to virtual address 0x00001200
  Test 2.3 PASS: Wrote data to virtual address 0x00002300
  Test 2: 3 subtests PASSED

[TEST 3] Testing Read Operations with Translation Hits
  Test 3.1 PASS: Read from virtual address 0x00000100, data: 0xdeadbeef_cafebabe
  Test 3.2 PASS: Read from virtual address 0x00001200, data: 0xcafebabe_deadbeef
  Test 3.3 PASS: Read from virtual address 0x00002300, data: 0xbaadf00d_deadc0de
  Test 3: 3 subtests PASSED

[TEST 4] Testing Translation Miss Errors
  Test 4.1 PASS: Translation miss detected for virtual page 0x5
  Test 4.2 PASS: Translation miss detected for write to virtual page 0x6
  Test 4: 2 subtests PASSED

[TEST 5] Testing Partial Write Operations
  Test 5.1 PASS: Partial write (masked) to virtual address 0x00000200
  Test 5.2 PASS: Read back partial write result: 0xffffffff_00000000
  Test 5: 2 subtests PASSED

[TEST 6] Testing Sequential Write-Read Operations
  Test 6.1 PASS: Wrote pattern to 4 sequential addresses
  Test 6.2 PASS: Read back pattern from 4 sequential addresses
  Test 6: 2 subtests PASSED

===== Memory Module Testbench Completed Successfully =====
Total TLB entries programmed: 3
```

## Limitations and Future Enhancements

### Current Limitations
1. Single-cycle latency TLB lookup (can become critical path for high-frequency designs)
2. Fixed round-robin replacement policy (no LRU or other advanced policies)
3. No TLB flush capability currently implemented
4. No memory protection or privilege levels

### Possible Future Enhancements
1. Multi-level page tables for larger address spaces
2. LRU replacement policy for TLB
3. TLB flush/invalidate operations
4. Memory protection attributes (read-only, no-execute, etc.)
5. Access control and privilege levels
6. Configurable memory attributes (cacheable, bufferable, etc.)
7. Multiple independent memory regions
8. Performance monitoring counters (hit/miss statistics)

## Verification Checklist

- [x] Module compiles without errors
- [x] RTL testbench exercises all major features
- [x] Address translation works correctly for hit cases
- [x] Translation miss errors are properly signaled
- [x] Write and read data paths are verified
- [x] TLB load interface works correctly
- [x] Partial write (masked) operations work correctly
- [x] Sequential operations are handled properly
- [x] Reset behavior verified

## References

- SystemVerilog LRM (IEEE 1800-2017)
- Memory architecture best practices
- TLB design patterns from modern microprocessors

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Author**: Hardware Design Team  
**Status**: Draft

