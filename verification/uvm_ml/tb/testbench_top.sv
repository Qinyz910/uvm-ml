module testbench_top;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  import mem_agent_pkg::*;
  import mem_sequences_pkg::*;
  import mem_env_pkg::*;
  import mem_tests_pkg::*;
  
  initial begin
    `uvm_info("TB_TOP", "=== UVM ML Memory Verification Testbench ===", UVM_LOW)
    `uvm_info("TB_TOP", "Starting UVM phases...", UVM_MEDIUM)
    
    run_test();
  end
  
  initial begin
    $timeformat(-9, 2, " ns", 10);
  end
  
  initial begin
    #1ms;
    `uvm_fatal("TB_TOP", "Simulation timeout after 1ms")
  end

endmodule
