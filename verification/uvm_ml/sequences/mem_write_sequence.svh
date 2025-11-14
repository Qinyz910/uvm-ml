`ifndef MEM_WRITE_SEQUENCE_SVH
`define MEM_WRITE_SEQUENCE_SVH

class mem_write_sequence extends mem_base_sequence;
  `uvm_object_utils(mem_write_sequence)

  rand int unsigned num_writes = 10;
  rand bit [63:0] start_addr = 64'h1000;
  
  constraint reasonable_num_c {
    num_writes inside {[1:100]};
  }

  function new(string name = "mem_write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction txn;
    
    `uvm_info("MEM_WR_SEQ", $sformatf("Starting %0d write transactions from addr 0x%0h", 
              num_writes, start_addr), UVM_MEDIUM)
    
    for (int i = 0; i < num_writes; i++) begin
      txn = mem_transaction::type_id::create($sformatf("write_txn_%0d", i));
      
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_WRITE;
        virt_addr >= start_addr;
        virt_addr < (start_addr + 64'h1000);
        byte_mask != 0;
      });
      finish_item(txn);
      
      `uvm_info("MEM_WR_SEQ", $sformatf("Write[%0d] addr=0x%0h data=0x%0h status=%s", 
                i, txn.virt_addr, txn.data, txn.status.name()), UVM_HIGH)
    end
    
    `uvm_info("MEM_WR_SEQ", "Write sequence completed", UVM_MEDIUM)
  endtask

endclass

`endif
