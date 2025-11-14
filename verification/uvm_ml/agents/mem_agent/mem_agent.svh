`ifndef MEM_AGENT_SVH
`define MEM_AGENT_SVH

class mem_agent extends uvm_agent;
  `uvm_component_utils(mem_agent)

  mem_config       cfg;
  mem_sequencer    sequencer;
  mem_driver       driver;
  mem_monitor      monitor;
  mem_coverage     coverage;

  uvm_analysis_port #(mem_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_AGENT", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
    
    uvm_config_db#(mem_config)::set(this, "*", "cfg", cfg);
    
    monitor = mem_monitor::type_id::create("monitor", this);
    
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = mem_sequencer::type_id::create("sequencer", this);
      driver = mem_driver::type_id::create("driver", this);
    end
    
    if (cfg.has_coverage) begin
      coverage = mem_coverage::type_id::create("coverage", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
    
    if (cfg.has_coverage) begin
      monitor.ap.connect(coverage.analysis_export);
    end
    
    ap = monitor.ap;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MEM_AGENT", "Agent reporting complete", UVM_LOW)
  endfunction

endclass

`endif
