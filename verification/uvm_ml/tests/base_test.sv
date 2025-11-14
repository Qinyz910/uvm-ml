`include "uvm_macros.svh"

class base_test extends uvm_test;
  `uvm_component_utils(base_test)
  
  mem_env env;
  mem_config cfg;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("BUILD", "Building base test", UVM_MEDIUM)
    
    cfg = mem_config::type_id::create("cfg");
    configure_test();
    
    uvm_config_db#(mem_config)::set(this, "*", "cfg", cfg);
    
    env = mem_env::type_id::create("env", this);
  endfunction
  
  virtual function void configure_test();
    cfg.is_active = UVM_ACTIVE;
    cfg.has_coverage = 1;
    cfg.has_scoreboard = 1;
  endfunction
  
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info("EOE", "Printing topology", UVM_LOW)
    uvm_top.print_topology();
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    `uvm_info("RUN", "Running base test", UVM_MEDIUM)
    
    phase.raise_objection(this);
    #100ns;
    phase.drop_objection(this);
  endtask
  
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("REPORT", "=== Base Test Completed ===", UVM_LOW)
  endfunction
endclass
