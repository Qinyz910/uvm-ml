`ifndef MEM_ENV_SVH
`define MEM_ENV_SVH

class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)

  mem_agent      agent;
  mem_scoreboard scoreboard;
  mem_config     cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(mem_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info("MEM_ENV", "Using default config", UVM_MEDIUM)
      cfg = mem_config::type_id::create("cfg");
    end
    
    uvm_config_db#(mem_config)::set(this, "*", "cfg", cfg);
    
    agent = mem_agent::type_id::create("agent", this);
    
    if (cfg.has_scoreboard) begin
      scoreboard = mem_scoreboard::type_id::create("scoreboard", this);
    end
    
    `uvm_info("MEM_ENV", "Environment built successfully", UVM_MEDIUM)
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    if (cfg.has_scoreboard) begin
      agent.ap.connect(scoreboard.analysis_export);
      `uvm_info("MEM_ENV", "Agent connected to scoreboard", UVM_MEDIUM)
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    `uvm_info("MEM_ENV", "Environment running", UVM_HIGH)
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MEM_ENV", "=== Environment Report ===", UVM_LOW)
    
    if (cfg.has_scoreboard) begin
      if (scoreboard.mismatch_count == 0 && scoreboard.transaction_count > 0) begin
        `uvm_info("MEM_ENV", $sformatf("PASS: All %0d transactions verified successfully", 
                  scoreboard.transaction_count), UVM_LOW)
      end else if (scoreboard.transaction_count == 0) begin
        `uvm_warning("MEM_ENV", "No transactions were processed")
      end else begin
        `uvm_error("MEM_ENV", $sformatf("FAIL: %0d mismatches out of %0d transactions", 
                   scoreboard.mismatch_count, scoreboard.transaction_count))
      end
    end
  endfunction

endclass

`endif
