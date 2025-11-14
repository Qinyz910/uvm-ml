// Integrated UVM Testbench with RTL and DPI Bridge
// This is the top-level testbench that connects UVM to RTL via DPI

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// Include all verification components
`include "mem_transaction.svh"
`include "mem_config.svh"
`include "mem_sequencer.svh"
`include "mem_driver.svh"
`include "mem_dpi_driver.svh"
`include "mem_monitor.svh"
`include "mem_enhanced_monitor.svh"
`include "mem_coverage.svh"
`include "mem_agent.svh"
`include "mem_enhanced_agent.svh"
`include "mem_scoreboard.svh"
`include "mem_env.svh"
`include "mem_smoke_sequence.svh"
`include "mem_stress_sequence.svh"
`include "mem_edge_sequence.svh"
`include "base_test.svh"
`include "smoke_test.svh"
`include "stress_test.svh"
`include "edge_test.svh"

// Top-level testbench module
module memory_integrated_tb;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Testbench configuration
  real CLOCK_PERIOD = 10.0; // 100 MHz
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
  end
  
  // Reset generation
  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end
  
  // DPI Bridge Module - Instantiates the RTL and provides DPI interface
  memory_dpi_bridge #(
    .VIRT_ADDR_WIDTH(32),
    .PHYS_ADDR_WIDTH(28),
    .MEM_DEPTH(16384),
    .PAGE_SIZE(4096),
    .DATA_WIDTH(64),
    .PT_ENTRIES(256)
  ) dut_dpi_bridge (
    .clk(clk),
    .rst_n(rst_n),
    .trace_enabled() // Debug output
  );
  
  // Interface for UVM to connect to (if needed for direct SV connections)
  memory_if mem_if(clk, rst_n);
  
  // Connect interface to DPI bridge signals
  assign mem_if.read_req_valid = dut_dpi_bridge.dpi_read_req_valid;
  assign mem_if.read_req_addr = dut_dpi_bridge.dpi_read_req_addr;
  assign mem_if.read_req_mask = dut_dpi_bridge.dpi_read_req_mask;
  assign mem_if.read_req_ready = dut_dpi_bridge.dpi_read_req_ready;
  assign mem_if.read_resp_valid = dut_dpi_bridge.dpi_read_resp_valid;
  assign mem_if.read_resp_data = dut_dpi_bridge.dpi_read_resp_data;
  assign mem_if.read_resp_status = dut_dpi_bridge.dpi_read_resp_status;
  assign dut_dpi_bridge.dpi_read_resp_ready = mem_if.read_resp_ready;
  
  assign mem_if.write_req_valid = dut_dpi_bridge.dpi_write_req_valid;
  assign mem_if.write_req_addr = dut_dpi_bridge.dpi_write_req_addr;
  assign mem_if.write_req_mask = dut_dpi_bridge.dpi_write_req_mask;
  assign mem_if.write_req_data = dut_dpi_bridge.dpi_write_req_data;
  assign mem_if.write_req_ready = dut_dpi_bridge.dpi_write_req_ready;
  assign mem_if.write_resp_valid = dut_dpi_bridge.dpi_write_resp_valid;
  assign mem_if.write_resp_status = dut_dpi_bridge.dpi_write_resp_status;
  assign dut_dpi_bridge.dpi_write_resp_ready = mem_if.write_resp_ready;
  
  assign mem_if.tlb_load_valid = dut_dpi_bridge.dpi_tlb_load_valid;
  assign mem_if.tlb_load_virt_base = dut_dpi_bridge.dpi_tlb_load_virt_base;
  assign mem_if.tlb_load_phys_base = dut_dpi_bridge.dpi_tlb_load_phys_base;
  assign mem_if.tlb_load_ready = dut_dpi_bridge.dpi_tlb_load_ready;
  assign mem_if.tlb_num_entries = dut_dpi_bridge.dpi_tlb_num_entries;
  
  // Testbench control
  initial begin
    $display("=== Memory Integrated Testbench Starting ===");
    $display("Clock Period: %0.1f ns (%0.0f MHz)", CLOCK_PERIOD, 1000.0/CLOCK_PERIOD);
    $display("Reset deasserted at %0t", $time);
    
    // Wait for reset to complete
    @(posedge rst_n);
    #50;
    
    // Run UVM test
    run_test();
    
    $display("=== Memory Integrated Testbench Complete ===");
  end
  
  // Waveform dump
  initial begin
    if ($value$plusargs("WAVES=%s", waves)) begin
      if (waves == "vcd") begin
        $dumpfile("memory_integrated_tb.vcd");
        $dumpvars(0, memory_integrated_tb);
      end else if (waves == "fsdb") begin
        $fsdbDumpfile("memory_integrated_tb.fsdb");
        $fsdbDumpvars(0, memory_integrated_tb);
      end
    end
  end
  
  // Timeout protection
  initial begin
    #1000000; // 1ms timeout
    $display("FATAL: Testbench timeout!");
    $finish;
  end

endmodule

// Memory interface definition (for direct SV connections if needed)
interface memory_if(input logic clk, input logic rst_n);
  // Read interface
  logic read_req_valid;
  logic [31:0] read_req_addr;
  logic [7:0] read_req_mask;
  logic read_req_ready;
  logic read_resp_valid;
  logic [63:0] read_resp_data;
  logic [3:0] read_resp_status;
  logic read_resp_ready;
  
  // Write interface
  logic write_req_valid;
  logic [31:0] write_req_addr;
  logic [7:0] write_req_mask;
  logic [63:0] write_req_data;
  logic write_req_ready;
  logic write_resp_valid;
  logic [3:0] write_resp_status;
  logic write_resp_ready;
  
  // TLB interface
  logic tlb_load_valid;
  logic [31:0] tlb_load_virt_base;
  logic [27:0] tlb_load_phys_base;
  logic tlb_load_ready;
  logic [7:0] tlb_num_entries;
  
  // Modports
  modport master (
    output read_req_valid, read_req_addr, read_req_mask, read_resp_ready,
    input read_req_ready, read_resp_valid, read_resp_data, read_resp_status,
    output write_req_valid, write_req_addr, write_req_mask, write_req_data, write_resp_ready,
    input write_req_ready, write_resp_valid, write_resp_status,
    output tlb_load_valid, tlb_load_virt_base, tlb_load_phys_base,
    input tlb_load_ready, tlb_num_entries
  );
  
  modport slave (
    input read_req_valid, read_req_addr, read_req_mask, read_resp_ready,
    output read_req_ready, read_resp_valid, read_resp_data, read_resp_status,
    input write_req_valid, write_req_addr, write_req_mask, write_req_data, write_resp_ready,
    output write_req_ready, write_resp_valid, write_resp_status,
    input tlb_load_valid, tlb_load_virt_base, tlb_load_phys_base,
    output tlb_load_ready, tlb_num_entries
  );
  
endinterface