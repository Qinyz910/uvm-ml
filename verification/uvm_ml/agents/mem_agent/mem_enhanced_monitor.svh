`ifndef MEM_ENHANCED_MONITOR_SVH
`define MEM_ENHANCED_MONITOR_SVH

// Enhanced memory monitor with functional coverage
class mem_enhanced_monitor extends mem_monitor;
  `uvm_component_utils(mem_enhanced_monitor)

  // Functional coverage
  covergroup mem_operation_cg with function sample(bit [63:0] addr, bit [7:0] mask, 
                                                   bit [63:0] data, mem_op_type_e op_type,
                                                   mem_status_e status);
    option.per_instance = 1;
    option.name = "mem_operation_cg";
    
    // Operation type coverage
    operation_type_cp: coverpoint op_type {
      bins read_op = {MEM_READ};
      bins write_op = {MEM_WRITE};
      bins tlb_load_op = {MEM_TLB_LOAD};
    }
    
    // Status coverage
    status_cp: coverpoint status {
      bins ok_status = {MEM_STATUS_OK};
      bins addr_error = {MEM_STATUS_ERR_ADDR};
      bins access_error = {MEM_STATUS_ERR_ACCESS};
      bins write_error = {MEM_STATUS_ERR_WRITE};
    }
    
    // Address ranges - page aligned boundaries
    address_range_cp: coverpoint addr[31:12] {
      bins low_pages   = {[0:1023]};
      bins mid_pages   = {[1024:2047]};
      bins high_pages  = {[2048:4095]};
      bins boundary_pages = {[4096:5119]};
    }
    
    // Page offset coverage
    page_offset_cp: coverpoint addr[11:0] {
      bins page_start = {0};
      bins page_middle = {[1:2046]};
      bins page_end = {2047};
      bins aligned_4 = {[0:2047]} with (item % 4 == 0);
      bins aligned_8 = {[0:2047]} with (item % 8 == 0);
    }
    
    // Byte mask coverage
    byte_mask_cp: coverpoint mask {
      bins full_mask = {8'hFF};
      bins single_byte[8] = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins even_bytes = {8'h55}; // 01010101
      bins odd_bytes = {8'hAA};  // 10101010
      bins other_masks = default;
    }
    
    // Data patterns
    data_pattern_cp: coverpoint data[7:0] {
      bins all_zeros = {0};
      bins all_ones = {8'hFF};
      bins alternating = {8'h55, 8'hAA};
      bins incrementing = {[1:10]};
      bins other_data = default;
    }
    
    // Cross coverage for critical scenarios
    operation_status_cross: cross operation_type_cp, status_cp {
      // Focus on error conditions
      bins read_errors = binsof(operation_type_cp.read_op) && binsof(status_cp.addr_error);
      bins write_errors = binsof(operation_type_cp.write_op) && binsof(status_cp.addr_error);
      bins tlb_success = binsof(operation_type_cp.tlb_load_op) && binsof(status_cp.ok_status);
    }
    
    boundary_cross: cross address_range_cp, page_offset_cp {
      // Focus on boundary conditions
      bins page_boundaries = binsof(page_offset_cp.page_start) || 
                             binsof(page_offset_cp.page_end);
    }
    
    mask_boundary_cross: cross byte_mask_cp, page_offset_cp {
      // Test different masks at different offsets
      bins partial_writes = binsof(byte_mask_cp.single_byte) && 
                            binsof(page_offset_cp.page_middle);
    }
  endgroup
  
  // TLB-specific coverage
  covergroup tlb_operation_cg with function sample(bit [63:0] virt_base, bit [63:0] phys_base,
                                                   mem_status_e status);
    option.per_instance = 1;
    option.name = "tlb_operation_cg";
    
    // Virtual base address ranges
    virt_base_cp: coverpoint virt_base[31:12] {
      bins low_virt_pages   = {[0:1023]};
      bins mid_virt_pages   = {[1024:2047]};
      bins high_virt_pages  = {[2048:4095]};
    }
    
    // Physical base address ranges  
    phys_base_cp: coverpoint phys_base[27:12] {
      bins low_phys_pages   = {[0:1023]};
      bins mid_phys_pages   = {[1024:2047]};
      bins high_phys_pages  = {[2048:4095]};
    }
    
    // TLB status
    tlb_status_cp: coverpoint status {
      bins tlb_ok = {MEM_STATUS_OK};
      bins tlb_errors = default;
    }
    
    // Cross coverage for translation scenarios
    translation_cross: cross virt_base_cp, phys_base_cp, tlb_status_cp {
      // Focus on successful translations
      bins successful_translations = binsof(tlb_status_cp.tlb_ok);
      
      // Identity mappings (virt == phys)
      bins identity_mappings = binsof(virt_base_cp) intersect binsof(phys_base_cp);
    }
  endgroup
  
  // Coverage statistics
  real mem_operation_coverage = 0.0;
  real tlb_operation_coverage = 0.0;
  
  // Translation hit/miss tracking
  int unsigned translation_hits = 0;
  int unsigned translation_misses = 0;
  int unsigned boundary_accesses = 0;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    mem_operation_cg = new();
    tlb_operation_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("MEM_ENH_MON", "Enhanced monitor with functional coverage", UVM_MEDIUM)
  endfunction

  virtual task monitor_transaction();
    mem_transaction txn;
    bit is_boundary_access;
    bit is_translation_hit;
    
    #1ns;
    
    txn = mem_transaction::type_id::create("monitored_txn");
    
    collect_transaction(txn);
    
    if (txn.response_ready) begin
      `uvm_info("MEM_ENH_MON", $sformatf("Monitoring transaction: %s", 
                txn.convert2string()), UVM_HIGH)
      
      // Update basic statistics
      transaction_count++;
      case (txn.op_type)
        MEM_READ:     read_count++;
        MEM_WRITE:    write_count++;
        MEM_TLB_LOAD: tlb_load_count++;
      endcase
      
      // Check for boundary access
      is_boundary_access = (txn.virt_addr[11:0] == 0) || 
                           (txn.virt_addr[11:0] == 4095) ||
                           (txn.virt_addr[11:0] < 8) || 
                           (txn.virt_addr[11:0] > 4088);
      
      if (is_boundary_access) begin
        boundary_accesses++;
        `uvm_info("MEM_ENH_MON", $sformatf("Boundary access detected: addr=0x%0h", 
                  txn.virt_addr), UVM_MEDIUM)
      end
      
      // Check translation hit/miss for non-TLB operations
      if (txn.op_type != MEM_TLB_LOAD) begin
        if (txn.status == MEM_STATUS_OK) begin
          translation_hits++;
        end else if (txn.status == MEM_STATUS_ERR_ADDR) begin
          translation_misses++;
        end
      end
      
      // Sample functional coverage
      if (txn.op_type == MEM_TLB_LOAD) begin
        tlb_operation_cg.sample(txn.tlb_virt_base, txn.tlb_phys_base, txn.status);
      end else begin
        mem_operation_cg.sample(txn.virt_addr, txn.byte_mask, txn.data, 
                               txn.op_type, txn.status);
      end
      
      // Update coverage statistics
      mem_operation_coverage = mem_operation_cg.get_coverage();
      tlb_operation_coverage = tlb_operation_cg.get_coverage();
      
      ap.write(txn);
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    `uvm_info("MEM_ENH_MON", "=== Enhanced Monitor Report ===", UVM_LOW)
    `uvm_info("MEM_ENH_MON", $sformatf("Translation Hits:    %0d", translation_hits), UVM_LOW)
    `uvm_info("MEM_ENH_MON", $sformatf("Translation Misses:  %0d", translation_misses), UVM_LOW)
    `uvm_info("MEM_ENH_MON", $sformatf("Boundary Accesses:  %0d", boundary_accesses), UVM_LOW)
    
    // Coverage report
    `uvm_info("MEM_ENH_MON", "=== Functional Coverage ===", UVM_LOW)
    `uvm_info("MEM_ENH_MON", $sformatf("Memory Operation Coverage: %.2f%%", 
              mem_operation_coverage), UVM_LOW)
    `uvm_info("MEM_ENH_MON", $sformatf("TLB Operation Coverage:     %.2f%%", 
              tlb_operation_coverage), UVM_LOW)
    
    // Coverage goals analysis
    if (mem_operation_coverage >= 95.0 && tlb_operation_coverage >= 95.0) begin
      `uvm_info("MEM_ENH_MON", "EXCELLENT: Coverage goals met (>95%)", UVM_LOW)
    end else if (mem_operation_coverage >= 80.0 && tlb_operation_coverage >= 80.0) begin
      `uvm_info("MEM_ENH_MON", "GOOD: Coverage goals mostly met (>80%)", UVM_LOW)
    end else begin
      `uvm_warning("MEM_ENH_MON", "LOW: Coverage below target (<80%)")
    end
    
    // Translation efficiency
    if ((translation_hits + translation_misses) > 0) begin
      real hit_rate = (real(translation_hits) / (translation_hits + translation_misses)) * 100.0;
      `uvm_info("MEM_ENH_MON", $sformatf("Translation Hit Rate: %.2f%%", hit_rate), UVM_LOW)
    end
  endfunction

  // Coverage utility functions
  function real get_total_coverage();
    return (mem_operation_coverage + tlb_operation_coverage) / 2.0;
  endfunction
  
  function bit coverage_goals_met(real threshold = 95.0);
    return (mem_operation_coverage >= threshold) && (tlb_operation_coverage >= threshold);
  endfunction

endclass

`endif