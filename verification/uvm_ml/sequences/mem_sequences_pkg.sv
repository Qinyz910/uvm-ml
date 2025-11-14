package mem_sequences_pkg;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  `include "mem_transaction.svh"
  `include "mem_base_sequence.svh"
  `include "mem_read_sequence.svh"
  `include "mem_write_sequence.svh"
  `include "mem_tlb_load_sequence.svh"
  `include "mem_smoke_sequence.svh"
  `include "mem_stress_sequence.svh"
  `include "mem_edge_sequence.svh"

endpackage
