`ifndef MEM_SEQUENCER_SVH
`define MEM_SEQUENCER_SVH

class mem_sequencer extends uvm_sequencer #(mem_transaction);
  `uvm_component_utils(mem_sequencer)

  mem_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_SEQ", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
  endfunction

endclass

`endif
