package mem_tests_pkg;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  import mem_agent_pkg::*;
  import mem_sequences_pkg::*;
  import mem_env_pkg::*;
  
  `include "base_test.sv"
  `include "smoke_test.sv"
  `include "stress_test.sv"
  `include "edge_test.sv"

endpackage
