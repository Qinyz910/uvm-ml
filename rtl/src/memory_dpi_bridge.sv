// SystemVerilog DPI Wrapper for Memory Module
// Provides DPI exports for C/SystemC to call RTL memory functions

`timescale 1ns/1ps

// Import DPI-C functions
import "DPI-C" context function int memory_dpi_c_init(input string rtl_module_path);
import "DPI-C" context function void memory_dpi_c_reset();
import "DPI-C" context function void memory_dpi_c_finalize();

import "DPI-C" context function int memory_dpi_c_read(
    input logic [63:0] virt_addr,
    input logic [7:0] byte_mask,
    output logic [63:0] data,
    output logic [31:0] timestamp
);

import "DPI-C" context function int memory_dpi_c_write(
    input logic [63:0] virt_addr,
    input logic [7:0] byte_mask,
    input logic [63:0] data,
    output logic [31:0] timestamp
);

import "DPI-C" context function int memory_dpi_c_tlb_load(
    input logic [63:0] virt_base,
    input logic [63:0] phys_base,
    output logic [31:0] timestamp
);

import "DPI-C" context function int memory_dpi_c_get_response(
    input int ctx_id,
    output int status,
    output logic [63:0] data,
    output logic [31:0] timestamp
);

import "DPI-C" context function int memory_dpi_c_get_tlb_entries();
import "DPI-C" context function int memory_dpi_c_is_ready();

import "DPI-C" context function void memory_dpi_c_enable_trace(input int enable);
import "DPI-C" context function void memory_dpi_c_dump_state();

// Export DPI functions to C
export "DPI-C" function sv_memory_dpi_init;
export "DPI-C" function sv_memory_dpi_reset;
export "DPI-C" function sv_memory_dpi_finalize;
export "DPI-C" function sv_memory_dpi_read;
export "DPI-C" function sv_memory_dpi_write;
export "DPI-C" function sv_memory_dpi_tlb_load;
export "DPI-C" function sv_memory_dpi_get_response;
export "DPI-C" function sv_memory_dpi_get_tlb_entries;
export "DPI-C" function sv_memory_dpi_is_ready;
export "DPI-C" function sv_memory_dpi_enable_trace;
export "DPI-C" function sv_memory_dpi_dump_state;

// Memory DPI Bridge Module
module memory_dpi_bridge #(
    parameter VIRT_ADDR_WIDTH = 32,
    parameter PHYS_ADDR_WIDTH = 28,
    parameter MEM_DEPTH = 16384,
    parameter PAGE_SIZE = 4096,
    parameter DATA_WIDTH = 64,
    parameter PT_ENTRIES = 256
) (
    input logic clk,
    input logic rst_n,
    
    // Debug trace output
    output logic trace_enabled
);

    // Instantiate the actual memory module
    memory #(
        .VIRT_ADDR_WIDTH(VIRT_ADDR_WIDTH),
        .PHYS_ADDR_WIDTH(PHYS_ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .PAGE_SIZE(PAGE_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .PT_ENTRIES(PT_ENTRIES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        
        // Read interface
        .read_req_valid(dpi_read_req_valid),
        .read_req_addr(dpi_read_req_addr),
        .read_req_mask(dpi_read_req_mask),
        .read_req_ready(dpi_read_req_ready),
        .read_resp_valid(dpi_read_resp_valid),
        .read_resp_data(dpi_read_resp_data),
        .read_resp_status(dpi_read_resp_status),
        .read_resp_ready(dpi_read_resp_ready),
        
        // Write interface
        .write_req_valid(dpi_write_req_valid),
        .write_req_addr(dpi_write_req_addr),
        .write_req_mask(dpi_write_req_mask),
        .write_req_data(dpi_write_req_data),
        .write_req_ready(dpi_write_req_ready),
        .write_resp_valid(dpi_write_resp_valid),
        .write_resp_status(dpi_write_resp_status),
        .write_resp_ready(dpi_write_resp_ready),
        
        // TLB interface
        .tlb_load_valid(dpi_tlb_load_valid),
        .tlb_load_virt_base(dpi_tlb_load_virt_base),
        .tlb_load_phys_base(dpi_tlb_load_phys_base),
        .tlb_load_ready(dpi_tlb_load_ready),
        
        // Control/Status
        .tlb_num_entries(dpi_tlb_num_entries)
    );

    // DPI control signals
    logic dpi_trace_enabled = 0;
    assign trace_enabled = dpi_trace_enabled;

    // DPI interface signals
    logic dpi_read_req_valid = 0;
    logic [VIRT_ADDR_WIDTH-1:0] dpi_read_req_addr;
    logic [(DATA_WIDTH/8)-1:0] dpi_read_req_mask;
    logic dpi_read_req_ready;
    logic dpi_read_resp_valid;
    logic [DATA_WIDTH-1:0] dpi_read_resp_data;
    logic [3:0] dpi_read_resp_status;
    logic dpi_read_resp_ready = 1;

    logic dpi_write_req_valid = 0;
    logic [VIRT_ADDR_WIDTH-1:0] dpi_write_req_addr;
    logic [(DATA_WIDTH/8)-1:0] dpi_write_req_mask;
    logic [DATA_WIDTH-1:0] dpi_write_req_data;
    logic dpi_write_req_ready;
    logic dpi_write_resp_valid;
    logic [3:0] dpi_write_resp_status;
    logic dpi_write_resp_ready = 1;

    logic dpi_tlb_load_valid = 0;
    logic [VIRT_ADDR_WIDTH-1:0] dpi_tlb_load_virt_base;
    logic [PHYS_ADDR_WIDTH-1:0] dpi_tlb_load_phys_base;
    logic dpi_tlb_load_ready;
    logic [$clog2(PT_ENTRIES)-1:0] dpi_tlb_num_entries;

    // DPI timestamp counter
    logic [31:0] dpi_timestamp = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dpi_timestamp <= 0;
        end else begin
            dpi_timestamp <= dpi_timestamp + 1;
        end
    end

    // DPI Export Functions - These are called from C
    
    function int sv_memory_dpi_init(input string rtl_module_path);
        $display("[Memory DPI] Initialized with module: %s", rtl_module_path);
        return 1; // Success
    endfunction

    function void sv_memory_dpi_reset();
        $display("[Memory DPI] Reset called");
    endfunction

    function void sv_memory_dpi_finalize();
        $display("[Memory DPI] Finalized");
    endfunction

    function int sv_memory_dpi_read(
        input logic [63:0] virt_addr,
        input logic [7:0] byte_mask,
        output logic [63:0] data,
        output logic [31:0] timestamp
    );
        logic [VIRT_ADDR_WIDTH-1:0] addr;
        logic [(DATA_WIDTH/8)-1:0] mask;
        
        addr = virt_addr[VIRT_ADDR_WIDTH-1:0];
        mask = byte_mask[(DATA_WIDTH/8)-1:0];
        
        if (dpi_trace_enabled) begin
            $display("[Memory DPI] READ: addr=0x%h mask=0x%h @%0t", addr, mask, $time);
        end
        
        // Initiate read request
        dpi_read_req_valid <= 1;
        dpi_read_req_addr <= addr;
        dpi_read_req_mask <= mask;
        
        // Wait for response (simplified for DPI)
        #10;
        
        dpi_read_req_valid <= 0;
        data = dpi_read_resp_data;
        timestamp = dpi_timestamp;
        
        return dpi_read_resp_status;
    endfunction

    function int sv_memory_dpi_write(
        input logic [63:0] virt_addr,
        input logic [7:0] byte_mask,
        input logic [63:0] data,
        output logic [31:0] timestamp
    );
        logic [VIRT_ADDR_WIDTH-1:0] addr;
        logic [(DATA_WIDTH/8)-1:0] mask;
        logic [DATA_WIDTH-1:0] wdata;
        
        addr = virt_addr[VIRT_ADDR_WIDTH-1:0];
        mask = byte_mask[(DATA_WIDTH/8)-1:0];
        wdata = data[DATA_WIDTH-1:0];
        
        if (dpi_trace_enabled) begin
            $display("[Memory DPI] WRITE: addr=0x%h mask=0x%h data=0x%h @%0t", 
                     addr, mask, wdata, $time);
        end
        
        // Initiate write request
        dpi_write_req_valid <= 1;
        dpi_write_req_addr <= addr;
        dpi_write_req_mask <= mask;
        dpi_write_req_data <= wdata;
        
        // Wait for response (simplified for DPI)
        #10;
        
        dpi_write_req_valid <= 0;
        timestamp = dpi_timestamp;
        
        return dpi_write_resp_status;
    endfunction

    function int sv_memory_dpi_tlb_load(
        input logic [63:0] virt_base,
        input logic [63:0] phys_base,
        output logic [31:0] timestamp
    );
        logic [VIRT_ADDR_WIDTH-1:0] vbase;
        logic [PHYS_ADDR_WIDTH-1:0] pbase;
        
        vbase = virt_base[VIRT_ADDR_WIDTH-1:0];
        pbase = phys_base[PHYS_ADDR_WIDTH-1:0];
        
        if (dpi_trace_enabled) begin
            $display("[Memory DPI] TLB_LOAD: virt=0x%h phys=0x%h @%0t", vbase, pbase, $time);
        end
        
        // Initiate TLB load
        dpi_tlb_load_valid <= 1;
        dpi_tlb_load_virt_base <= vbase;
        dpi_tlb_load_phys_base <= pbase;
        
        // Wait for response (simplified for DPI)
        #10;
        
        dpi_tlb_load_valid <= 0;
        timestamp = dpi_timestamp;
        
        return 0; // Success status
    endfunction

    function int sv_memory_dpi_get_response(
        input int ctx_id,
        output int status,
        output logic [63:0] data,
        output logic [31:0] timestamp
    );
        // Simplified implementation
        status = 0;
        data = 0;
        timestamp = dpi_timestamp;
        return 1; // Success
    endfunction

    function int sv_memory_dpi_get_tlb_entries();
        return dpi_tlb_num_entries;
    endfunction

    function int sv_memory_dpi_is_ready();
        return 1; // Always ready in this implementation
    endfunction

    function void sv_memory_dpi_enable_trace(input int enable);
        dpi_trace_enabled = enable;
        $display("[Memory DPI] Trace %s", enable ? "enabled" : "disabled");
    endfunction

    function void sv_memory_dpi_dump_state();
        $display("[Memory DPI] State Dump:");
        $display("  TLB Entries: %0d", dpi_tlb_num_entries);
        $display("  Timestamp: %0d", dpi_timestamp);
        $display("  Trace Enabled: %0d", dpi_trace_enabled);
    endfunction

endmodule