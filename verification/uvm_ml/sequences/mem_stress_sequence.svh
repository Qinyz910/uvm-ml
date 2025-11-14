`ifndef MEM_STRESS_SEQUENCE_SVH
`define MEM_STRESS_SEQUENCE_SVH

class mem_stress_sequence extends mem_base_sequence;
  `uvm_object_utils(mem_stress_sequence)

  rand int unsigned num_transactions = 1000;
  rand bit [63:0] addr_range_start = 64'h1000;
  rand bit [63:0] addr_range_end = 64'h10000;
  
  constraint reasonable_params_c {
    num_transactions inside {[100:5000]};
    addr_range_end > addr_range_start;
    addr_range_start[11:0] == 0;
  }

  function new(string name = "mem_stress_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction txn;
    mem_tlb_load_sequence tlb_seq;
    int unsigned num_pages;
    
    `uvm_info("MEM_STRESS", $sformatf("=== Starting Stress Test: %0d transactions ===", 
              num_transactions), UVM_LOW)
    
    num_pages = (addr_range_end - addr_range_start) / 64'h1000;
    if (num_pages > 16) num_pages = 16;
    
    `uvm_info("MEM_STRESS", $sformatf("Loading %0d TLB entries", num_pages), UVM_MEDIUM)
    tlb_seq = mem_tlb_load_sequence::type_id::create("tlb_seq");
    tlb_seq.num_entries = num_pages;
    tlb_seq.base_virt_addr = addr_range_start;
    tlb_seq.base_phys_addr = 64'h10000;
    tlb_seq.start(m_sequencer);
    
    `uvm_info("MEM_STRESS", "Starting random read/write stress", UVM_MEDIUM)
    for (int i = 0; i < num_transactions; i++) begin
      txn = mem_transaction::type_id::create($sformatf("stress_txn_%0d", i));
      
      start_item(txn);
      assert(txn.randomize() with {
        op_type inside {MEM_READ, MEM_WRITE};
        virt_addr >= addr_range_start;
        virt_addr < addr_range_end;
        byte_mask != 0;
      });
      finish_item(txn);
      
      if ((i % 100) == 0) begin
        `uvm_info("MEM_STRESS", $sformatf("Progress: %0d/%0d transactions", 
                  i, num_transactions), UVM_MEDIUM)
      end
    end
    
    `uvm_info("MEM_STRESS", "=== Stress Test Completed ===", UVM_LOW)
  endtask

endclass

`endif
