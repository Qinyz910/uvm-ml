`ifndef MEM_CONFIG_SVH
`define MEM_CONFIG_SVH

class mem_config extends uvm_object;
  `uvm_object_utils(mem_config)

  bit is_active = 1;
  bit has_coverage = 1;
  bit has_scoreboard = 1;
  
  int unsigned virt_addr_width = 64;
  int unsigned phys_addr_width = 64;
  int unsigned page_size = 4096;
  int unsigned data_width = 64;
  int unsigned mem_depth = 1024;
  int unsigned tlb_entries = 16;
  
  bit enable_address_translation = 1;
  bit check_alignment = 1;
  
  function new(string name = "mem_config");
    super.new(name);
  endfunction

  function void display(string prefix = "");
    `uvm_info("MEM_CONFIG", $sformatf("%sConfiguration:", prefix), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  is_active       : %0d", is_active), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  has_coverage    : %0d", has_coverage), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  has_scoreboard  : %0d", has_scoreboard), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  virt_addr_width : %0d", virt_addr_width), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  phys_addr_width : %0d", phys_addr_width), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  page_size       : %0d", page_size), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  data_width      : %0d", data_width), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  mem_depth       : %0d", mem_depth), UVM_MEDIUM)
    `uvm_info("MEM_CONFIG", $sformatf("  tlb_entries     : %0d", tlb_entries), UVM_MEDIUM)
  endfunction

endclass

`endif
