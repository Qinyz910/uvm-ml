`ifndef MEM_READ_SEQUENCE_SVH
`define MEM_READ_SEQUENCE_SVH

class mem_read_sequence extends mem_base_sequence;
  `uvm_object_utils(mem_read_sequence)

  rand int unsigned num_reads = 10;
  rand bit [63:0] start_addr = 64'h1000;
  
  constraint reasonable_num_c {
    num_reads inside {[1:100]};
  }

  function new(string name = "mem_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction txn;
    
    `uvm_info("MEM_RD_SEQ", $sformatf("Starting %0d read transactions from addr 0x%0h", 
              num_reads, start_addr), UVM_MEDIUM)
    
    for (int i = 0; i < num_reads; i++) begin
      txn = mem_transaction::type_id::create($sformatf("read_txn_%0d", i));
      
      start_item(txn);
      assert(txn.randomize() with {
        op_type == MEM_READ;
        virt_addr >= start_addr;
        virt_addr < (start_addr + 64'h1000);
        byte_mask != 0;
      });
      finish_item(txn);
      
      `uvm_info("MEM_RD_SEQ", $sformatf("Read[%0d] addr=0x%0h data=0x%0h status=%s", 
                i, txn.virt_addr, txn.data, txn.status.name()), UVM_HIGH)
    end
    
    `uvm_info("MEM_RD_SEQ", "Read sequence completed", UVM_MEDIUM)
  endtask

endclass

`endif
