`ifndef MEM_DRIVER_SVH
`define MEM_DRIVER_SVH

class mem_driver extends uvm_driver #(mem_transaction);
  `uvm_component_utils(mem_driver)

  mem_config cfg;
  
  uvm_analysis_port #(mem_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_DRV", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_transaction txn;
    
    forever begin
      seq_item_port.get_next_item(txn);
      `uvm_info("MEM_DRV", $sformatf("Driving transaction: %s", txn.convert2string()), UVM_HIGH)
      
      drive_transaction(txn);
      
      ap.write(txn);
      
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(mem_transaction txn);
    txn.timestamp = $time;
    
    case (txn.op_type)
      MEM_READ: begin
        `uvm_info("MEM_DRV", $sformatf("Driving READ: addr=0x%0h mask=0x%0h", 
                  txn.virt_addr, txn.byte_mask), UVM_MEDIUM)
        drive_read(txn);
      end
      
      MEM_WRITE: begin
        `uvm_info("MEM_DRV", $sformatf("Driving WRITE: addr=0x%0h mask=0x%0h data=0x%0h", 
                  txn.virt_addr, txn.byte_mask, txn.data), UVM_MEDIUM)
        drive_write(txn);
      end
      
      MEM_TLB_LOAD: begin
        `uvm_info("MEM_DRV", $sformatf("Driving TLB_LOAD: virt=0x%0h phys=0x%0h", 
                  txn.tlb_virt_base, txn.tlb_phys_base), UVM_MEDIUM)
        drive_tlb_load(txn);
      end
      
      default: begin
        `uvm_error("MEM_DRV", $sformatf("Unknown operation type: %0d", txn.op_type))
      end
    endcase
    
    txn.response_ready = 1;
  endtask

  virtual task drive_read(mem_transaction txn);
    #10ns;
    txn.status = MEM_STATUS_OK;
    txn.data = $urandom_range(0, 64'hFFFFFFFF);
  endtask

  virtual task drive_write(mem_transaction txn);
    #10ns;
    txn.status = MEM_STATUS_OK;
  endtask

  virtual task drive_tlb_load(mem_transaction txn);
    #10ns;
    txn.status = MEM_STATUS_OK;
  endtask

endclass

`endif
