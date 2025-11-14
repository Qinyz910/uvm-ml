`ifndef MEM_MONITOR_SVH
`define MEM_MONITOR_SVH

class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)

  mem_config cfg;
  
  uvm_analysis_port #(mem_transaction) ap;
  
  int unsigned transaction_count = 0;
  int unsigned read_count = 0;
  int unsigned write_count = 0;
  int unsigned tlb_load_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_MON", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      monitor_transaction();
    end
  endtask

  virtual task monitor_transaction();
    mem_transaction txn;
    
    #1ns;
    
    txn = mem_transaction::type_id::create("monitored_txn");
    
    collect_transaction(txn);
    
    if (txn.response_ready) begin
      `uvm_info("MEM_MON", $sformatf("Monitored transaction: %s", txn.convert2string()), UVM_HIGH)
      
      transaction_count++;
      case (txn.op_type)
        MEM_READ:     read_count++;
        MEM_WRITE:    write_count++;
        MEM_TLB_LOAD: tlb_load_count++;
      endcase
      
      ap.write(txn);
    end
  endtask

  virtual task collect_transaction(mem_transaction txn);
    #5ns;
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MEM_MON", "=== Monitor Statistics ===", UVM_LOW)
    `uvm_info("MEM_MON", $sformatf("Total transactions: %0d", transaction_count), UVM_LOW)
    `uvm_info("MEM_MON", $sformatf("  Reads:     %0d", read_count), UVM_LOW)
    `uvm_info("MEM_MON", $sformatf("  Writes:    %0d", write_count), UVM_LOW)
    `uvm_info("MEM_MON", $sformatf("  TLB Loads: %0d", tlb_load_count), UVM_LOW)
  endfunction

endclass

`endif
