`include "uvm_macros.svh"

class stress_test extends base_test;
  `uvm_component_utils(stress_test)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    mem_stress_sequence stress_seq;
    
    `uvm_info("STRESS_TEST", "=== Starting Stress Test ===", UVM_LOW)
    
    phase.raise_objection(this);
    
    stress_seq = mem_stress_sequence::type_id::create("stress_seq");
    stress_seq.num_transactions = 1000;
    stress_seq.start(env.agent.sequencer);
    
    #100ns;
    
    phase.drop_objection(this);
    
    `uvm_info("STRESS_TEST", "=== Stress Test Finished ===", UVM_LOW)
  endtask
  
endclass
