`ifndef MEM_SCOREBOARD_SVH
`define MEM_SCOREBOARD_SVH

class mem_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mem_scoreboard)

  uvm_analysis_imp #(mem_transaction, mem_scoreboard) analysis_export;
  
  mem_config cfg;
  
  int unsigned match_count = 0;
  int unsigned mismatch_count = 0;
  int unsigned transaction_count = 0;
  
  bit [63:0] shadow_memory [bit[63:0]];
  bit [63:0] tlb_map [bit[63:0]];
  
  int unsigned active_tlb_entries = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_SB", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
  endfunction

  virtual function void write(mem_transaction txn);
    transaction_count++;
    
    `uvm_info("MEM_SB", $sformatf("Checking transaction [%0d]: %s", 
              transaction_count, txn.convert2string()), UVM_HIGH)
    
    case (txn.op_type)
      MEM_READ: begin
        check_read_transaction(txn);
      end
      
      MEM_WRITE: begin
        check_write_transaction(txn);
      end
      
      MEM_TLB_LOAD: begin
        check_tlb_load_transaction(txn);
      end
      
      default: begin
        `uvm_error("MEM_SB", $sformatf("Unknown operation type: %0d", txn.op_type))
      end
    endcase
  endfunction

  virtual function void check_read_transaction(mem_transaction txn);
    bit [63:0] phys_addr;
    bit [63:0] expected_data;
    bit translation_ok;
    
    translation_ok = translate_address(txn.virt_addr, phys_addr);
    
    if (!translation_ok) begin
      if (txn.status == MEM_STATUS_ERR_ADDR) begin
        match_count++;
        `uvm_info("MEM_SB", "Read: Translation error correctly reported", UVM_MEDIUM)
      end else begin
        mismatch_count++;
        `uvm_error("MEM_SB", $sformatf("Read: Expected translation error, got %s", 
                   txn.status.name()))
      end
      return;
    end
    
    if (shadow_memory.exists(phys_addr)) begin
      expected_data = apply_byte_mask(shadow_memory[phys_addr], txn.byte_mask);
      
      if (txn.data == expected_data && txn.status == MEM_STATUS_OK) begin
        match_count++;
        `uvm_info("MEM_SB", $sformatf("Read MATCH: addr=0x%0h data=0x%0h", 
                  txn.virt_addr, txn.data), UVM_HIGH)
      end else begin
        mismatch_count++;
        `uvm_error("MEM_SB", $sformatf("Read MISMATCH: addr=0x%0h expected=0x%0h got=0x%0h", 
                   txn.virt_addr, expected_data, txn.data))
      end
    end else begin
      if (txn.status == MEM_STATUS_OK) begin
        match_count++;
        `uvm_info("MEM_SB", $sformatf("Read: New location addr=0x%0h data=0x%0h", 
                  txn.virt_addr, txn.data), UVM_HIGH)
      end
    end
  endfunction

  virtual function void check_write_transaction(mem_transaction txn);
    bit [63:0] phys_addr;
    bit translation_ok;
    
    translation_ok = translate_address(txn.virt_addr, phys_addr);
    
    if (!translation_ok) begin
      if (txn.status == MEM_STATUS_ERR_ADDR) begin
        match_count++;
        `uvm_info("MEM_SB", "Write: Translation error correctly reported", UVM_MEDIUM)
      end else begin
        mismatch_count++;
        `uvm_error("MEM_SB", $sformatf("Write: Expected translation error, got %s", 
                   txn.status.name()))
      end
      return;
    end
    
    if (txn.status == MEM_STATUS_OK) begin
      update_shadow_memory(phys_addr, txn.data, txn.byte_mask);
      match_count++;
      `uvm_info("MEM_SB", $sformatf("Write: addr=0x%0h data=0x%0h mask=0x%0h", 
                txn.virt_addr, txn.data, txn.byte_mask), UVM_HIGH)
    end else begin
      mismatch_count++;
      `uvm_error("MEM_SB", $sformatf("Write: Unexpected status %s", txn.status.name()))
    end
  endfunction

  virtual function void check_tlb_load_transaction(mem_transaction txn);
    if (txn.status == MEM_STATUS_OK) begin
      tlb_map[txn.tlb_virt_base] = txn.tlb_phys_base;
      active_tlb_entries++;
      match_count++;
      `uvm_info("MEM_SB", $sformatf("TLB Load: virt=0x%0h -> phys=0x%0h (entries=%0d)", 
                txn.tlb_virt_base, txn.tlb_phys_base, active_tlb_entries), UVM_MEDIUM)
    end else begin
      mismatch_count++;
      `uvm_error("MEM_SB", $sformatf("TLB Load: Unexpected status %s", txn.status.name()))
    end
  endfunction

  virtual function bit translate_address(bit [63:0] virt_addr, output bit [63:0] phys_addr);
    bit [63:0] page_base;
    bit [11:0] page_offset;
    
    page_base = {virt_addr[63:12], 12'h0};
    page_offset = virt_addr[11:0];
    
    if (tlb_map.exists(page_base)) begin
      phys_addr = tlb_map[page_base] + page_offset;
      return 1;
    end
    
    return 0;
  endfunction

  virtual function bit [63:0] apply_byte_mask(bit [63:0] data, bit [7:0] mask);
    bit [63:0] result = 0;
    for (int i = 0; i < 8; i++) begin
      if (mask[i]) begin
        result[i*8 +: 8] = data[i*8 +: 8];
      end
    end
    return result;
  endfunction

  virtual function void update_shadow_memory(bit [63:0] addr, bit [63:0] data, bit [7:0] mask);
    bit [63:0] old_data = 0;
    
    if (shadow_memory.exists(addr)) begin
      old_data = shadow_memory[addr];
    end
    
    for (int i = 0; i < 8; i++) begin
      if (mask[i]) begin
        old_data[i*8 +: 8] = data[i*8 +: 8];
      end
    end
    
    shadow_memory[addr] = old_data;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    `uvm_info("MEM_SB", "=== Scoreboard Final Report ===", UVM_LOW)
    `uvm_info("MEM_SB", $sformatf("Total transactions: %0d", transaction_count), UVM_LOW)
    `uvm_info("MEM_SB", $sformatf("Matches:            %0d", match_count), UVM_LOW)
    `uvm_info("MEM_SB", $sformatf("Mismatches:         %0d", mismatch_count), UVM_LOW)
    `uvm_info("MEM_SB", $sformatf("Active TLB entries: %0d", active_tlb_entries), UVM_LOW)
    
    if (mismatch_count > 0) begin
      `uvm_error("MEM_SB", $sformatf("Test FAILED with %0d mismatches!", mismatch_count))
    end else begin
      `uvm_info("MEM_SB", "Test PASSED: All transactions matched!", UVM_LOW)
    end
  endfunction

endclass

`endif
