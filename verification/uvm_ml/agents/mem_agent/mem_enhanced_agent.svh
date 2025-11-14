`ifndef MEM_ENHANCED_AGENT_SVH
`define MEM_ENHANCED_AGENT_SVH

// Enhanced memory agent with DPI integration and functional coverage
class mem_enhanced_agent extends mem_agent;
  `uvm_component_utils(mem_enhanced_agent)

  // Enhanced components
  mem_dpi_driver dpi_driver;
  mem_enhanced_monitor enhanced_monitor;
  
  // Configuration
  bit enable_dpi = 1;
  bit enable_enhanced_monitor = 1;
  bit enable_coverage = 1;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_ENH_AGENT", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
    
    uvm_config_db#(mem_config)::set(this, "*", "cfg", cfg);
    
    // Create sequencer
    if (cfg.is_active) begin
      sequencer = mem_sequencer::type_id::create("sequencer", this);
    end
    
    // Create enhanced driver if DPI is enabled
    if (cfg.is_active && enable_dpi) begin
      `uvm_info("MEM_ENH_AGENT", "Creating DPI-enabled driver", UVM_MEDIUM)
      dpi_driver = mem_dpi_driver::type_id::create("dpi_driver", this);
      
      // Configure DPI driver
      dpi_driver.enable_dpi = enable_dpi;
      dpi_driver.enable_trace = 0; // Can be overridden via config
    end else if (cfg.is_active) begin
      // Fall back to regular driver
      driver = mem_driver::type_id::create("driver", this);
    end
    
    // Create enhanced monitor
    if (enable_enhanced_monitor) begin
      `uvm_info("MEM_ENH_AGENT", "Creating enhanced monitor with coverage", UVM_MEDIUM)
      enhanced_monitor = mem_enhanced_monitor::type_id::create("enhanced_monitor", this);
    end else begin
      // Fall back to regular monitor
      monitor = mem_monitor::type_id::create("monitor", this);
    end
    
    // Create coverage collector if enabled
    if (cfg.has_coverage && enable_coverage && enable_enhanced_monitor) begin
      coverage = mem_coverage::type_id::create("coverage", this);
    end
    
    `uvm_info("MEM_ENH_AGENT", "Enhanced agent built successfully", UVM_MEDIUM)
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect DPI driver
    if (cfg.is_active && enable_dpi && dpi_driver != null) begin
      if (sequencer != null) begin
        dpi_driver.seq_item_port.connect(sequencer.seq_item_export);
      end
      
      // Connect driver analysis port to monitor
      if (enhanced_monitor != null) begin
        dpi_driver.ap.connect(enhanced_monitor.analysis_export);
      end else if (monitor != null) begin
        dpi_driver.ap.connect(monitor.analysis_export);
      end
      
      `uvm_info("MEM_ENH_AGENT", "DPI driver connected", UVM_MEDIUM)
    end else if (cfg.is_active && driver != null) begin
      // Regular driver connections
      if (sequencer != null) begin
        driver.seq_item_port.connect(sequencer.seq_item_export);
      end
      
      if (monitor != null) begin
        driver.ap.connect(monitor.analysis_export);
      end
    end
    
    // Connect enhanced monitor analysis port
    if (enhanced_monitor != null) begin
      ap = enhanced_monitor.ap;
    end else if (monitor != null) begin
      ap = monitor.ap;
    end
    
    // Connect coverage
    if (cfg.has_coverage && enable_coverage) begin
      if (enhanced_monitor != null) begin
        enhanced_monitor.ap.connect(coverage.analysis_export);
      end else if (monitor != null) begin
        monitor.ap.connect(coverage.analysis_export);
      end
    end
    
    `uvm_info("MEM_ENH_AGENT", "Enhanced agent connections complete", UVM_MEDIUM)
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    if (enable_dpi && dpi_driver != null) begin
      `uvm_info("MEM_ENH_AGENT", "Enhanced agent running with DPI integration", UVM_HIGH)
    end else begin
      `uvm_info("MEM_ENH_AGENT", "Enhanced agent running without DPI", UVM_HIGH)
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    `uvm_info("MEM_ENH_AGENT", "=== Enhanced Agent Report ===", UVM_LOW)
    `uvm_info("MEM_ENH_AGENT", $sformatf("DPI Enabled:           %0d", enable_dpi), UVM_LOW)
    `uvm_info("MEM_ENH_AGENT", $sformatf("Enhanced Monitor:     %0d", enable_enhanced_monitor), UVM_LOW)
    `uvm_info("MEM_ENH_AGENT", $sformatf("Coverage Enabled:      %0d", enable_coverage), UVM_LOW)
    
    // Report coverage from enhanced monitor
    if (enhanced_monitor != null) begin
      real total_cov = enhanced_monitor.get_total_coverage();
      `uvm_info("MEM_ENH_AGENT", $sformatf("Total Coverage: %.2f%%", total_cov), UVM_LOW)
      
      if (enhanced_monitor.coverage_goals_met()) begin
        `uvm_info("MEM_ENH_AGENT", "COVERAGE GOALS MET (>95%)", UVM_LOW)
      end else begin
        `uvm_warning("MEM_ENH_AGENT", "Coverage goals not met")
      end
    end
  endfunction

endclass

`endif