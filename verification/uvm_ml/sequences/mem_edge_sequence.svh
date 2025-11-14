`ifndef MEM_EDGE_SEQUENCE_SVH
`define MEM_EDGE_SEQUENCE_SVH

class mem_edge_sequence extends mem_base_sequence;
  `uvm_object_utils(mem_edge_sequence)

  function new(string name = "mem_edge_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction txn;
    
    `uvm_info("MEM_EDGE", "=== Starting Edge Case Test Sequence ===", UVM_LOW)
    
    `uvm_info("MEM_EDGE", "Test 1: Partial byte masks", UVM_MEDIUM)
    test_partial_masks();
    
    `uvm_info("MEM_EDGE", "Test 2: Unaligned addresses", UVM_MEDIUM)
    test_unaligned_addresses();
    
    `uvm_info("MEM_EDGE", "Test 3: Boundary addresses", UVM_MEDIUM)
    test_boundary_addresses();
    
    `uvm_info("MEM_EDGE", "Test 4: TLB edge cases", UVM_MEDIUM)
    test_tlb_edge_cases();
    
    `uvm_info("MEM_EDGE", "Test 5: Zero data patterns", UVM_MEDIUM)
    test_zero_patterns();
    
    `uvm_info("MEM_EDGE", "Test 6: Maximum value patterns", UVM_MEDIUM)
    test_max_patterns();
    
    `uvm_info("MEM_EDGE", "=== Edge Case Test Completed ===", UVM_LOW)
  endtask

  virtual task test_partial_masks();
    mem_transaction txn;
    bit [7:0] masks[] = {8'h01, 8'h03, 8'h0F, 8'h3F, 8'h55, 8'hAA, 8'hF0};
    
    foreach (masks[i]) begin
      txn = mem_transaction::type_id::create($sformatf("partial_mask_txn_%0d", i));
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_WRITE;
        byte_mask == masks[i];
        virt_addr == 64'h1000 + (i * 8);
      });
      finish_item(txn);
    end
  endtask

  virtual task test_unaligned_addresses();
    mem_transaction txn;
    
    for (int offset = 1; offset < 8; offset++) begin
      txn = mem_transaction::type_id::create($sformatf("unaligned_txn_%0d", offset));
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_READ;
        virt_addr == (64'h1000 + offset);
        byte_mask == 8'hFF;
      });
      finish_item(txn);
    end
  endtask

  virtual task test_boundary_addresses();
    mem_transaction txn;
    bit [63:0] boundary_addrs[] = {64'h0, 64'hFF8, 64'h1000, 64'hFFF8};
    
    foreach (boundary_addrs[i]) begin
      txn = mem_transaction::type_id::create($sformatf("boundary_txn_%0d", i));
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_READ;
        virt_addr == boundary_addrs[i];
        byte_mask == 8'hFF;
      });
      finish_item(txn);
    end
  endtask

  virtual task test_tlb_edge_cases();
    mem_transaction txn;
    
    for (int i = 0; i < 20; i++) begin
      txn = mem_transaction::type_id::create($sformatf("tlb_overflow_txn_%0d", i));
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_TLB_LOAD;
        tlb_virt_base == (64'h1000 + (i * 64'h1000));
        tlb_phys_base == (64'h10000 + (i * 64'h1000));
      });
      finish_item(txn);
    end
  endtask

  virtual task test_zero_patterns();
    mem_transaction txn;
    
    for (int i = 0; i < 5; i++) begin
      txn = mem_transaction::type_id::create($sformatf("zero_txn_%0d", i));
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_WRITE;
        data == 0;
        virt_addr == (64'h1000 + (i * 8));
        byte_mask == 8'hFF;
      });
      finish_item(txn);
    end
  endtask

  virtual task test_max_patterns();
    mem_transaction txn;
    
    for (int i = 0; i < 5; i++) begin
      txn = mem_transaction::type_id::create($sformatf("max_txn_%0d", i));
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_WRITE;
        data == 64'hFFFFFFFFFFFFFFFF;
        virt_addr == (64'h1000 + (i * 8));
        byte_mask == 8'hFF;
      });
      finish_item(txn);
    end
  endtask

endclass

`endif
