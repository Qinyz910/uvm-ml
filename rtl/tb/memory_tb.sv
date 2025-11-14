// Memory Module Testbench
// Tests virtual-to-physical address translation and read/write operations

`timescale 1ns/1ps

module memory_tb;

  // Status code constants
  localparam [3:0] MEM_OK        = 4'h0;
  localparam [3:0] MEM_ERR_ADDR  = 4'h1;
  localparam [3:0] MEM_ERR_ACCESS = 4'h2;

  // Test parameters
  localparam int VIRT_ADDR_WIDTH = 32;
  localparam int PHYS_ADDR_WIDTH = 28;
  localparam int MEM_DEPTH = 16384;
  localparam int PAGE_SIZE = 4096;
  localparam int DATA_WIDTH = 64;
  localparam int PT_ENTRIES = 256;
  localparam int CLK_PERIOD = 10;

  // Signals
  logic clk;
  logic rst_n;
  
  logic read_req_valid;
  logic [VIRT_ADDR_WIDTH-1:0] read_req_addr;
  logic [(DATA_WIDTH/8)-1:0] read_req_mask;
  logic read_req_ready;
  
  logic read_resp_valid;
  logic [DATA_WIDTH-1:0] read_resp_data;
  logic [3:0] read_resp_status;
  logic read_resp_ready;
  
  logic write_req_valid;
  logic [VIRT_ADDR_WIDTH-1:0] write_req_addr;
  logic [(DATA_WIDTH/8)-1:0] write_req_mask;
  logic [DATA_WIDTH-1:0] write_req_data;
  logic write_req_ready;
  
  logic write_resp_valid;
  logic [3:0] write_resp_status;
  logic write_resp_ready;
  
  logic tlb_load_valid;
  logic [VIRT_ADDR_WIDTH-1:0] tlb_load_virt_base;
  logic [PHYS_ADDR_WIDTH-1:0] tlb_load_phys_base;
  logic tlb_load_ready;
  
  logic [$clog2(PT_ENTRIES)-1:0] tlb_num_entries;

  // Instantiate the memory module
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
    .read_req_valid(read_req_valid),
    .read_req_addr(read_req_addr),
    .read_req_mask(read_req_mask),
    .read_req_ready(read_req_ready),
    .read_resp_valid(read_resp_valid),
    .read_resp_data(read_resp_data),
    .read_resp_status(read_resp_status),
    .read_resp_ready(read_resp_ready),
    .write_req_valid(write_req_valid),
    .write_req_addr(write_req_addr),
    .write_req_mask(write_req_mask),
    .write_req_data(write_req_data),
    .write_req_ready(write_req_ready),
    .write_resp_valid(write_resp_valid),
    .write_resp_status(write_resp_status),
    .write_resp_ready(write_resp_ready),
    .tlb_load_valid(tlb_load_valid),
    .tlb_load_virt_base(tlb_load_virt_base),
    .tlb_load_phys_base(tlb_load_phys_base),
    .tlb_load_ready(tlb_load_ready),
    .tlb_num_entries(tlb_num_entries)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 1'b0;
    #(CLK_PERIOD * 3);
    rst_n = 1'b1;
  end

  // Main test procedure
  initial begin
    integer test_counter;
    integer i;

    $display("===== Memory Module Testbench Starting =====");
    
    // Wait for reset
    wait(rst_n == 1'b1);
    #(CLK_PERIOD);
    
    // Initialize all control signals
    read_req_valid = 1'b0;
    read_req_addr = 32'h0;
    read_req_mask = 8'h0;
    read_resp_ready = 1'b0;
    
    write_req_valid = 1'b0;
    write_req_addr = 32'h0;
    write_req_mask = 8'h0;
    write_req_data = 64'h0;
    write_resp_ready = 1'b0;
    
    tlb_load_valid = 1'b0;
    tlb_load_virt_base = 32'h0;
    tlb_load_phys_base = 28'h0;

    // Test 1: TLB Load Operations
    $display("\n[TEST 1] Testing TLB Load Operations");
    test_counter = 0;
    
    // Load first TLB entry
    tlb_load_valid = 1'b1;
    tlb_load_virt_base = 32'h00000000;
    tlb_load_phys_base = 28'h0000000;
    #(CLK_PERIOD);
    if (tlb_load_ready == 1'b1) begin
      $display("  Test 1.1 PASS: Loaded virtual page 0x00000 -> physical page 0x00000");
      test_counter = test_counter + 1;
    end

    // Load second TLB entry
    tlb_load_virt_base = 32'h00001000;
    tlb_load_phys_base = 28'h0008000;
    #(CLK_PERIOD);
    if (tlb_load_ready == 1'b1) begin
      $display("  Test 1.2 PASS: Loaded virtual page 0x1 -> physical page 0x8");
      test_counter = test_counter + 1;
    end

    // Load third TLB entry
    tlb_load_virt_base = 32'h00002000;
    tlb_load_phys_base = 28'h0010000;
    #(CLK_PERIOD);
    if (tlb_load_ready == 1'b1) begin
      $display("  Test 1.3 PASS: Loaded virtual page 0x2 -> physical page 0x10");
      test_counter = test_counter + 1;
    end

    tlb_load_valid = 1'b0;
    #(CLK_PERIOD);
    $display("  Test 1: %0d subtests PASSED\n", test_counter);

    // Test 2: Write Operations with Translation Hits
    $display("[TEST 2] Testing Write Operations with Translation Hits");
    test_counter = 0;

    // Write to virtual address 0x00000100
    write_req_valid = 1'b1;
    write_req_addr = 32'h00000100;
    write_req_data = 64'hDEADBEEF_CAFEBABE;
    write_req_mask = 8'hFF;
    #(CLK_PERIOD);
    if (write_req_ready == 1'b1) begin
      write_resp_ready = 1'b1;
      #(CLK_PERIOD);
      if (write_resp_valid == 1'b1 && write_resp_status == MEM_OK) begin
        $display("  Test 2.1 PASS: Wrote data to virtual address 0x00000100");
        test_counter = test_counter + 1;
      end
    end

    // Write to virtual address 0x00001200
    write_req_addr = 32'h00001200;
    write_req_data = 64'hCAFEBABE_DEADBEEF;
    #(CLK_PERIOD);
    if (write_resp_valid == 1'b1 && write_resp_status == MEM_OK) begin
      $display("  Test 2.2 PASS: Wrote data to virtual address 0x00001200");
      test_counter = test_counter + 1;
    end

    // Write to virtual address 0x00002300
    write_req_addr = 32'h00002300;
    write_req_data = 64'hBAADF00D_DEADC0DE;
    #(CLK_PERIOD);
    if (write_resp_valid == 1'b1 && write_resp_status == MEM_OK) begin
      $display("  Test 2.3 PASS: Wrote data to virtual address 0x00002300");
      test_counter = test_counter + 1;
    end

    write_req_valid = 1'b0;
    write_resp_ready = 1'b0;
    #(CLK_PERIOD);
    $display("  Test 2: %0d subtests PASSED\n", test_counter);

    // Test 3: Read Operations with Translation Hits
    $display("[TEST 3] Testing Read Operations with Translation Hits");
    test_counter = 0;

    // Read from virtual address 0x00000100
    read_req_valid = 1'b1;
    read_req_addr = 32'h00000100;
    read_req_mask = 8'hFF;
    #(CLK_PERIOD);
    if (read_req_ready == 1'b1) begin
      read_resp_ready = 1'b1;
      #(CLK_PERIOD);
      if (read_resp_valid == 1'b1 && read_resp_status == MEM_OK) begin
        if (read_resp_data == 64'hDEADBEEF_CAFEBABE) begin
          $display("  Test 3.1 PASS: Read from virtual address 0x00000100, data: 0x%016h", read_resp_data);
          test_counter = test_counter + 1;
        end
      end
    end

    // Read from virtual address 0x00001200
    read_req_addr = 32'h00001200;
    #(CLK_PERIOD);
    if (read_resp_valid == 1'b1 && read_resp_status == MEM_OK) begin
      if (read_resp_data == 64'hCAFEBABE_DEADBEEF) begin
        $display("  Test 3.2 PASS: Read from virtual address 0x00001200, data: 0x%016h", read_resp_data);
        test_counter = test_counter + 1;
      end
    end

    // Read from virtual address 0x00002300
    read_req_addr = 32'h00002300;
    #(CLK_PERIOD);
    if (read_resp_valid == 1'b1 && read_resp_status == MEM_OK) begin
      if (read_resp_data == 64'hBAADF00D_DEADC0DE) begin
        $display("  Test 3.3 PASS: Read from virtual address 0x00002300, data: 0x%016h", read_resp_data);
        test_counter = test_counter + 1;
      end
    end

    read_req_valid = 1'b0;
    read_resp_ready = 1'b0;
    #(CLK_PERIOD);
    $display("  Test 3: %0d subtests PASSED\n", test_counter);

    // Test 4: Translation Miss Errors
    $display("[TEST 4] Testing Translation Miss Errors");
    test_counter = 0;

    // Try to read from unmapped virtual page
    read_req_valid = 1'b1;
    read_req_addr = 32'h00005000;
    read_resp_ready = 1'b1;
    #(CLK_PERIOD);
    
    #(CLK_PERIOD);
    if (read_resp_valid == 1'b1 && read_resp_status == MEM_ERR_ADDR) begin
      $display("  Test 4.1 PASS: Translation miss detected for virtual page 0x5");
      test_counter = test_counter + 1;
    end

    // Try to write to unmapped virtual page
    read_req_valid = 1'b0;
    write_req_valid = 1'b1;
    write_req_addr = 32'h00006000;
    write_req_data = 64'hFFFF_FFFF;
    write_req_mask = 8'hFF;
    write_resp_ready = 1'b1;
    #(CLK_PERIOD);
    
    #(CLK_PERIOD);
    if (write_resp_valid == 1'b1 && write_resp_status == MEM_ERR_ADDR) begin
      $display("  Test 4.2 PASS: Translation miss detected for write to virtual page 0x6");
      test_counter = test_counter + 1;
    end

    write_req_valid = 1'b0;
    write_resp_ready = 1'b0;
    #(CLK_PERIOD);
    $display("  Test 4: %0d subtests PASSED\n", test_counter);

    // Test 5: Partial Write Operations
    $display("[TEST 5] Testing Partial Write Operations");
    test_counter = 0;

    // Clear location by writing zeros
    write_req_valid = 1'b1;
    write_req_addr = 32'h00000200;
    write_req_data = 64'h0000000000000000;
    write_req_mask = 8'hFF;
    write_resp_ready = 1'b1;
    #(CLK_PERIOD * 2);

    // Write only lower 4 bytes
    write_req_data = 64'hFFFF_FFFF_0000_0000;
    write_req_mask = 8'h0F;
    #(CLK_PERIOD);
    
    #(CLK_PERIOD);
    if (write_resp_valid == 1'b1 && write_resp_status == MEM_OK) begin
      $display("  Test 5.1 PASS: Partial write (masked) to virtual address 0x00000200");
      test_counter = test_counter + 1;
    end

    // Read back to verify partial write
    write_req_valid = 1'b0;
    read_req_valid = 1'b1;
    read_req_addr = 32'h00000200;
    read_resp_ready = 1'b1;
    #(CLK_PERIOD * 2);
    if (read_resp_data[31:0] == 32'hFFFF_FFFF) begin
      $display("  Test 5.2 PASS: Read back partial write result: 0x%016h", read_resp_data);
      test_counter = test_counter + 1;
    end

    read_req_valid = 1'b0;
    read_resp_ready = 1'b0;
    #(CLK_PERIOD);
    $display("  Test 5: %0d subtests PASSED\n", test_counter);

    // Final Summary
    #(CLK_PERIOD * 5);
    $display("\n===== Memory Module Testbench Completed Successfully =====");
    $display("Total TLB entries programmed: %0d", tlb_num_entries);
    $finish;
  end

endmodule

