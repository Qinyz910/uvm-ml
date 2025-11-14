`ifndef MEM_SMOKE_SEQUENCE_SVH
`define MEM_SMOKE_SEQUENCE_SVH

class mem_smoke_sequence extends mem_base_sequence;
  `uvm_object_utils(mem_smoke_sequence)

  mem_tlb_load_sequence tlb_seq;
  mem_write_sequence write_seq;
  mem_read_sequence read_seq;

  function new(string name = "mem_smoke_sequence");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("MEM_SMOKE", "=== Starting Smoke Test Sequence ===", UVM_LOW)
    
    `uvm_info("MEM_SMOKE", "Step 1: Loading TLB entries", UVM_MEDIUM)
    tlb_seq = mem_tlb_load_sequence::type_id::create("tlb_seq");
    tlb_seq.num_entries = 4;
    tlb_seq.base_virt_addr = 64'h1000;
    tlb_seq.base_phys_addr = 64'h10000;
    tlb_seq.start(m_sequencer);
    
    `uvm_info("MEM_SMOKE", "Step 2: Writing data to memory", UVM_MEDIUM)
    write_seq = mem_write_sequence::type_id::create("write_seq");
    write_seq.num_writes = 10;
    write_seq.start_addr = 64'h1000;
    write_seq.start(m_sequencer);
    
    `uvm_info("MEM_SMOKE", "Step 3: Reading data from memory", UVM_MEDIUM)
    read_seq = mem_read_sequence::type_id::create("read_seq");
    read_seq.num_reads = 10;
    read_seq.start_addr = 64'h1000;
    read_seq.start(m_sequencer);
    
    `uvm_info("MEM_SMOKE", "=== Smoke Test Sequence Completed ===", UVM_LOW)
  endtask

endclass

`endif
