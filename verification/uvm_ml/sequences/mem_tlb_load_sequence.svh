`ifndef MEM_TLB_LOAD_SEQUENCE_SVH
`define MEM_TLB_LOAD_SEQUENCE_SVH

class mem_tlb_load_sequence extends mem_base_sequence;
  `uvm_object_utils(mem_tlb_load_sequence)

  rand int unsigned num_entries = 4;
  rand bit [63:0] base_virt_addr = 64'h1000;
  rand bit [63:0] base_phys_addr = 64'h10000;
  
  constraint reasonable_num_c {
    num_entries inside {[1:16]};
  }
  
  constraint page_aligned_c {
    base_virt_addr[11:0] == 0;
    base_phys_addr[11:0] == 0;
  }

  function new(string name = "mem_tlb_load_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction txn;
    
    `uvm_info("MEM_TLB_SEQ", $sformatf("Loading %0d TLB entries starting virt=0x%0h phys=0x%0h", 
              num_entries, base_virt_addr, base_phys_addr), UVM_MEDIUM)
    
    for (int i = 0; i < num_entries; i++) begin
      txn = mem_transaction::type_id::create($sformatf("tlb_load_txn_%0d", i));
      
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_TLB_LOAD;
        tlb_virt_base == (base_virt_addr + (i * 64'h1000));
        tlb_phys_base == (base_phys_addr + (i * 64'h1000));
      });
      finish_item(txn);
      
      `uvm_info("MEM_TLB_SEQ", $sformatf("TLB[%0d] virt=0x%0h -> phys=0x%0h status=%s", 
                i, txn.tlb_virt_base, txn.tlb_phys_base, txn.status.name()), UVM_HIGH)
    end
    
    `uvm_info("MEM_TLB_SEQ", "TLB load sequence completed", UVM_MEDIUM)
  endtask

endclass

`endif
