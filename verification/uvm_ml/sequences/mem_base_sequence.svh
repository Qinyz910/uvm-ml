`ifndef MEM_BASE_SEQUENCE_SVH
`define MEM_BASE_SEQUENCE_SVH

class mem_base_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_base_sequence)

  function new(string name = "mem_base_sequence");
    super.new(name);
  endfunction

  virtual task pre_body();
    if (starting_phase != null) begin
      starting_phase.raise_objection(this, $sformatf("%s starting", get_name()));
    end
  endtask

  virtual task post_body();
    if (starting_phase != null) begin
      starting_phase.drop_objection(this, $sformatf("%s completed", get_name()));
    end
  endtask

endclass

`endif
