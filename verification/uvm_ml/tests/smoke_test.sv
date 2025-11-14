`include "uvm_macros.svh"

class smoke_test extends base_test;
  `uvm_component_utils(smoke_test)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    mem_smoke_sequence smoke_seq;
    
    `uvm_info("SMOKE_TEST", "=== Starting Smoke Test ===", UVM_LOW)
    
    phase.raise_objection(this);
    
    smoke_seq = mem_smoke_sequence::type_id::create("smoke_seq");
    smoke_seq.start(env.agent.sequencer);
    
    #100ns;
    
    phase.drop_objection(this);
    
    `uvm_info("SMOKE_TEST", "=== Smoke Test Finished ===", UVM_LOW)
  endtask
  
endclass
