// Memory module with virtual-to-physical address translation
// Implements a configurable memory system with page table translation

`timescale 1ns/1ps

module memory
#(
  parameter int VIRT_ADDR_WIDTH = 32,
  parameter int PHYS_ADDR_WIDTH = 28,
  parameter int MEM_DEPTH = 16384,
  parameter int PAGE_SIZE = 4096,
  parameter int DATA_WIDTH = 64,
  parameter int PT_ENTRIES = 256
) (
  input  logic                          clk,
  input  logic                          rst_n,
  
  // Read request channel
  input  logic                          read_req_valid,
  input  logic [VIRT_ADDR_WIDTH-1:0]   read_req_addr,
  input  logic [(DATA_WIDTH/8)-1:0]     read_req_mask,
  output logic                          read_req_ready,
  
  // Read response channel
  output logic                          read_resp_valid,
  output logic [DATA_WIDTH-1:0]         read_resp_data,
  output logic [3:0]                    read_resp_status,
  input  logic                          read_resp_ready,
  
  // Write request channel
  input  logic                          write_req_valid,
  input  logic [VIRT_ADDR_WIDTH-1:0]   write_req_addr,
  input  logic [(DATA_WIDTH/8)-1:0]     write_req_mask,
  input  logic [DATA_WIDTH-1:0]         write_req_data,
  output logic                          write_req_ready,
  
  // Write response channel
  output logic                          write_resp_valid,
  output logic [3:0]                    write_resp_status,
  input  logic                          write_resp_ready,
  
  // TLB management
  input  logic                          tlb_load_valid,
  input  logic [VIRT_ADDR_WIDTH-1:0]   tlb_load_virt_base,
  input  logic [PHYS_ADDR_WIDTH-1:0]   tlb_load_phys_base,
  output logic                          tlb_load_ready,
  
  // Control/Status
  output logic [$clog2(PT_ENTRIES)-1:0] tlb_num_entries
);

  // Status code constants
  localparam [3:0] MEM_OK        = 4'h0;
  localparam [3:0] MEM_ERR_ADDR  = 4'h1;
  localparam [3:0] MEM_ERR_ACCESS = 4'h2;

  // Page offset width calculation
  localparam int PAGE_OFFSET_WIDTH = $clog2(PAGE_SIZE);
  localparam int VIRT_PAGE_BITS = VIRT_ADDR_WIDTH - PAGE_OFFSET_WIDTH;
  localparam int PHYS_PAGE_BITS = PHYS_ADDR_WIDTH - PAGE_OFFSET_WIDTH;
  localparam int MEM_ADDR_WIDTH = $clog2(MEM_DEPTH);

  // Memory storage
  logic [DATA_WIDTH-1:0] mem_array [0:MEM_DEPTH-1];

  // Translation Lookaside Buffer (page table)
  logic [VIRT_ADDR_WIDTH-1:0] tlb_virt [0:PT_ENTRIES-1];
  logic [PHYS_ADDR_WIDTH-1:0] tlb_phys [0:PT_ENTRIES-1];
  logic tlb_valid [0:PT_ENTRIES-1];
  logic [$clog2(PT_ENTRIES)-1:0] tlb_write_ptr;

  // Signals for pipelined read/write
  logic [PHYS_ADDR_WIDTH-1:0] translated_read_addr;
  logic [PHYS_ADDR_WIDTH-1:0] translated_write_addr;
  logic [3:0] read_translate_status;
  logic [3:0] write_translate_status;

  // Initialize memory and TLB
  initial begin
    integer i;
    for (i = 0; i < MEM_DEPTH; i++) begin
      mem_array[i] = {DATA_WIDTH{1'b0}};
    end
    for (i = 0; i < PT_ENTRIES; i++) begin
      tlb_valid[i] = 1'b0;
      tlb_phys[i] = {PHYS_ADDR_WIDTH{1'b0}};
      tlb_virt[i] = {VIRT_ADDR_WIDTH{1'b0}};
    end
    tlb_write_ptr = {($clog2(PT_ENTRIES)){1'b0}};
  end

  // Virtual-to-Physical address translation for read
  always_comb begin
    integer i;
    logic [VIRT_PAGE_BITS-1:0] virt_page;
    logic [PAGE_OFFSET_WIDTH-1:0] page_offset;
    logic found;

    virt_page = read_req_addr[VIRT_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH];
    page_offset = read_req_addr[PAGE_OFFSET_WIDTH-1:0];

    found = 1'b0;
    translated_read_addr = {PHYS_ADDR_WIDTH{1'b0}};
    read_translate_status = MEM_OK;

    for (i = 0; i < PT_ENTRIES; i++) begin
      if (!found && tlb_valid[i] && 
          tlb_virt[i][VIRT_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH] == virt_page) begin
        found = 1'b1;
        translated_read_addr = {tlb_phys[i][PHYS_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH], page_offset};
      end
    end

    if (!found) begin
      read_translate_status = MEM_ERR_ADDR;
      translated_read_addr = {PHYS_ADDR_WIDTH{1'b0}};
    end
  end

  // Virtual-to-Physical address translation for write
  always_comb begin
    integer i;
    logic [VIRT_PAGE_BITS-1:0] virt_page;
    logic [PAGE_OFFSET_WIDTH-1:0] page_offset;
    logic found;

    virt_page = write_req_addr[VIRT_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH];
    page_offset = write_req_addr[PAGE_OFFSET_WIDTH-1:0];

    found = 1'b0;
    translated_write_addr = {PHYS_ADDR_WIDTH{1'b0}};
    write_translate_status = MEM_OK;

    for (i = 0; i < PT_ENTRIES; i++) begin
      if (!found && tlb_valid[i] && 
          tlb_virt[i][VIRT_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH] == virt_page) begin
        found = 1'b1;
        translated_write_addr = {tlb_phys[i][PHYS_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH], page_offset};
      end
    end

    if (!found) begin
      write_translate_status = MEM_ERR_ADDR;
      translated_write_addr = {PHYS_ADDR_WIDTH{1'b0}};
    end
  end

  // Read request handler
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      read_resp_valid <= 1'b0;
      read_resp_data <= {DATA_WIDTH{1'b0}};
      read_resp_status <= MEM_OK;
    end else begin
      if (read_req_valid && read_req_ready) begin
        read_resp_valid <= 1'b1;
        read_resp_status <= read_translate_status;
        
        if (read_translate_status == MEM_OK) begin
          read_resp_data <= mem_array[translated_read_addr[MEM_ADDR_WIDTH-1:0]];
        end else begin
          read_resp_data <= {DATA_WIDTH{1'b0}};
        end
      end else if (read_resp_ready && read_resp_valid) begin
        read_resp_valid <= 1'b0;
      end
    end
  end

  // Write request handler
  always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
      write_resp_valid <= 1'b0;
      write_resp_status <= MEM_OK;
    end else begin
      if (write_req_valid && write_req_ready) begin
        write_resp_valid <= 1'b1;
        write_resp_status <= write_translate_status;
        
        if (write_translate_status == MEM_OK) begin
          for (i = 0; i < (DATA_WIDTH/8); i++) begin
            if (write_req_mask[i]) begin
              mem_array[translated_write_addr[MEM_ADDR_WIDTH-1:0]][8*i +: 8] <= write_req_data[8*i +: 8];
            end
          end
        end
      end else if (write_resp_ready && write_resp_valid) begin
        write_resp_valid <= 1'b0;
      end
    end
  end

  // TLB load handler
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tlb_write_ptr <= {($clog2(PT_ENTRIES)){1'b0}};
    end else begin
      if (tlb_load_valid && tlb_load_ready) begin
        tlb_valid[tlb_write_ptr] <= 1'b1;
        tlb_virt[tlb_write_ptr] <= tlb_load_virt_base;
        tlb_phys[tlb_write_ptr] <= tlb_load_phys_base;
        
        if (tlb_write_ptr < ($clog2(PT_ENTRIES)'(PT_ENTRIES - 1))) begin
          tlb_write_ptr <= tlb_write_ptr + 1;
        end else begin
          tlb_write_ptr <= {($clog2(PT_ENTRIES)){1'b0}};
        end
      end
    end
  end

  // Ready signals (combinatorial - module is always ready)
  assign read_req_ready = 1'b1;
  assign write_req_ready = 1'b1;
  assign tlb_load_ready = 1'b1;

  // Status output
  assign tlb_num_entries = tlb_write_ptr;

endmodule

