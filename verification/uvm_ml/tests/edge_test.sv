`include "uvm_macros.svh"

class edge_test extends base_test;
  `uvm_component_utils(edge_test)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    mem_edge_sequence edge_seq;
    
    `uvm_info("EDGE_TEST", "=== Starting Edge Case Test ===", UVM_LOW)
    
    phase.raise_objection(this);
    
    edge_seq = mem_edge_sequence::type_id::create("edge_seq");
    edge_seq.start(env.agent.sequencer);
    
    #100ns;
    
    phase.drop_objection(this);
    
    `uvm_info("EDGE_TEST", "=== Edge Case Test Finished ===", UVM_LOW)
  endtask
  
endclass
