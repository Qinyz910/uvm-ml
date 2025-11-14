`ifndef MEM_COVERAGE_SVH
`define MEM_COVERAGE_SVH

class mem_coverage extends uvm_subscriber #(mem_transaction);
  `uvm_component_utils(mem_coverage)

  mem_transaction txn;
  mem_config cfg;

  covergroup mem_cg;
    op_type_cp: coverpoint txn.op_type {
      bins read     = {MEM_READ};
      bins write    = {MEM_WRITE};
      bins tlb_load = {MEM_TLB_LOAD};
    }
    
    status_cp: coverpoint txn.status {
      bins ok        = {MEM_STATUS_OK};
      bins err_addr  = {MEM_STATUS_ERR_ADDR};
      bins err_acc   = {MEM_STATUS_ERR_ACC};
      bins err_write = {MEM_STATUS_ERR_WRITE};
      bins pending   = {MEM_STATUS_PENDING};
    }
    
    byte_mask_cp: coverpoint txn.byte_mask {
      bins full      = {8'hFF};
      bins partial[] = {[1:254]};
      bins empty     = {0};
    }
    
    addr_align_cp: coverpoint txn.virt_addr[2:0] {
      bins aligned   = {0};
      bins unaligned = {[1:7]};
    }
    
    op_status_cross: cross op_type_cp, status_cp {
      ignore_bins read_write_err = binsof(op_type_cp.read) && binsof(status_cp.err_write);
      ignore_bins write_write_err = binsof(op_type_cp.write) && binsof(status_cp.err_write);
    }
    
    op_mask_cross: cross op_type_cp, byte_mask_cp {
      ignore_bins tlb_with_mask = binsof(op_type_cp.tlb_load) && (binsof(byte_mask_cp.full) || 
                                                                    binsof(byte_mask_cp.partial) ||
                                                                    binsof(byte_mask_cp.empty));
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mem_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_COV", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
  endfunction

  function void write(mem_transaction t);
    txn = t;
    mem_cg.sample();
    `uvm_info("MEM_COV", $sformatf("Coverage: %.2f%%", mem_cg.get_coverage()), UVM_HIGH)
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MEM_COV", "=== Coverage Report ===", UVM_LOW)
    `uvm_info("MEM_COV", $sformatf("Total Coverage: %.2f%%", mem_cg.get_coverage()), UVM_LOW)
  endfunction

endclass

`endif
