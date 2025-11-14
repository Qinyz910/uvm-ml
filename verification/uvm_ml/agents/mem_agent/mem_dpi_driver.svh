`ifndef MEM_DPI_DRIVER_SVH
`define MEM_DPI_DRIVER_SVH

// DPI-enabled memory driver that interfaces with RTL via DPI
class mem_dpi_driver extends mem_driver;
  `uvm_component_utils(mem_dpi_driver)

  // DPI function imports
  import "DPI-C" function int chandle memory_dpi_init(string rtl_module_path);
  import "DPI-C" function void memory_dpi_reset();
  import "DPI-C" function void memory_dpi_finalize();
  
  import "DPI-C" function int memory_dpi_read(
    input logic [63:0] virt_addr,
    input logic [7:0] byte_mask,
    output logic [63:0] data,
    output logic [31:0] timestamp
  );
  
  import "DPI-C" function int memory_dpi_write(
    input logic [63:0] virt_addr,
    input logic [7:0] byte_mask,
    input logic [63:0] data,
    output logic [31:0] timestamp
  );
  
  import "DPI-C" function int memory_dpi_tlb_load(
    input logic [63:0] virt_base,
    input logic [63:0] phys_base,
    output logic [31:0] timestamp
  );
  
  import "DPI-C" function int memory_dpi_get_tlb_entries();
  import "DPI-C" function void memory_dpi_enable_trace(input int enable);

  // Configuration
  bit enable_dpi = 1;
  bit enable_trace = 0;
  string rtl_module_path = "memory_dpi_bridge";
  
  // Statistics
  int unsigned dpi_read_count = 0;
  int unsigned dpi_write_count = 0;
  int unsigned dpi_tlb_count = 0;
  int unsigned dpi_error_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (enable_dpi) begin
      `uvm_info("MEM_DPI_DRV", "Initializing DPI interface", UVM_MEDIUM)
      
      // Initialize DPI
      if (!memory_dpi_init(rtl_module_path)) begin
        `uvm_fatal("MEM_DPI_DRV", "Failed to initialize Memory DPI")
      end
      
      if (enable_trace) begin
        memory_dpi_enable_trace(1);
      end
      
      `uvm_info("MEM_DPI_DRV", "DPI interface initialized successfully", UVM_MEDIUM)
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_transaction txn;
    
    if (enable_dpi) begin
      `uvm_info("MEM_DPI_DRV", "Starting DPI-enabled driver", UVM_MEDIUM)
      
      forever begin
        seq_item_port.get_next_item(txn);
        `uvm_info("MEM_DPI_DRV", $sformatf("Driving transaction via DPI: %s", 
                  txn.convert2string()), UVM_HIGH)
        
        drive_transaction_dpi(txn);
        
        ap.write(txn);
        
        seq_item_port.item_done();
      end
    end else begin
      // Fall back to parent implementation
      super.run_phase(phase);
    end
  endtask

  // DPI-based transaction driving
  virtual task drive_transaction_dpi(mem_transaction txn);
    int dpi_status;
    logic [63:0] read_data;
    logic [31:0] timestamp;
    
    txn.timestamp = $time;
    
    case (txn.op_type)
      MEM_READ: begin
        `uvm_info("MEM_DPI_DRV", $sformatf("DPI READ: addr=0x%0h mask=0x%0h", 
                  txn.virt_addr, txn.byte_mask), UVM_MEDIUM)
        
        dpi_status = memory_dpi_read(txn.virt_addr, txn.byte_mask, read_data, timestamp);
        txn.data = read_data;
        txn.status = convert_dpi_status(dpi_status);
        
        if (dpi_status == 0) begin // Success
          dpi_read_count++;
          `uvm_info("MEM_DPI_DRV", $sformatf("DPI READ SUCCESS: data=0x%0h", 
                    read_data), UVM_HIGH)
        end else begin
          dpi_error_count++;
          `uvm_error("MEM_DPI_DRV", $sformatf("DPI READ FAILED: status=%0d", dpi_status))
        end
      end
      
      MEM_WRITE: begin
        `uvm_info("MEM_DPI_DRV", $sformatf("DPI WRITE: addr=0x%0h mask=0x%0h data=0x%0h", 
                  txn.virt_addr, txn.byte_mask, txn.data), UVM_MEDIUM)
        
        dpi_status = memory_dpi_write(txn.virt_addr, txn.byte_mask, txn.data, timestamp);
        txn.status = convert_dpi_status(dpi_status);
        
        if (dpi_status == 0) begin // Success
          dpi_write_count++;
          `uvm_info("MEM_DPI_DRV", "DPI WRITE SUCCESS", UVM_HIGH)
        end else begin
          dpi_error_count++;
          `uvm_error("MEM_DPI_DRV", $sformatf("DPI WRITE FAILED: status=%0d", dpi_status))
        end
      end
      
      MEM_TLB_LOAD: begin
        `uvm_info("MEM_DPI_DRV", $sformatf("DPI TLB_LOAD: virt=0x%0h phys=0x%0h", 
                  txn.tlb_virt_base, txn.tlb_phys_base), UVM_MEDIUM)
        
        dpi_status = memory_dpi_tlb_load(txn.tlb_virt_base, txn.tlb_phys_base, timestamp);
        txn.status = convert_dpi_status(dpi_status);
        
        if (dpi_status == 0) begin // Success
          dpi_tlb_count++;
          `uvm_info("MEM_DPI_DRV", "DPI TLB_LOAD SUCCESS", UVM_HIGH)
        end else begin
          dpi_error_count++;
          `uvm_error("MEM_DPI_DRV", $sformatf("DPI TLB_LOAD FAILED: status=%0d", dpi_status))
        end
      end
      
      default: begin
        `uvm_error("MEM_DPI_DRV", $sformatf("Unknown operation type: %0d", txn.op_type))
        txn.status = MEM_STATUS_ERR_ACCESS;
      end
    endcase
    
    txn.response_ready = 1;
  endtask

  // Convert DPI status to UVM status
  virtual function mem_status_e convert_dpi_status(int dpi_status);
    case (dpi_status)
      0: return MEM_STATUS_OK;
      1: return MEM_STATUS_ERR_ADDR;
      2: return MEM_STATUS_ERR_ACCESS;
      3: return MEM_STATUS_ERR_WRITE;
      default: return MEM_STATUS_ERR_ACCESS;
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    if (enable_dpi) begin
      `uvm_info("MEM_DPI_DRV", "=== DPI Driver Statistics ===", UVM_LOW)
      `uvm_info("MEM_DPI_DRV", $sformatf("DPI Reads:     %0d", dpi_read_count), UVM_LOW)
      `uvm_info("MEM_DPI_DRV", $sformatf("DPI Writes:    %0d", dpi_write_count), UVM_LOW)
      `uvm_info("MEM_DPI_DRV", $sformatf("DPI TLB Loads: %0d", dpi_tlb_count), UVM_LOW)
      `uvm_info("MEM_DPI_DRV", $sformatf("DPI Errors:    %0d", dpi_error_count), UVM_LOW)
      
      int total_dpi_ops = dpi_read_count + dpi_write_count + dpi_tlb_count;
      if (total_dpi_ops > 0) begin
        real error_rate = (real(dpi_error_count) / total_dpi_ops) * 100.0;
        `uvm_info("MEM_DPI_DRV", $sformatf("Error Rate: %.2f%%", error_rate), UVM_LOW)
      end
      
      // Report TLB status from DPI
      int tlb_entries = memory_dpi_get_tlb_entries();
      `uvm_info("MEM_DPI_DRV", $sformatf("Active TLB Entries: %0d", tlb_entries), UVM_LOW)
    end
  endfunction

  function void final_phase(uvm_phase phase);
    if (enable_dpi) begin
      `uvm_info("MEM_DPI_DRV", "Finalizing DPI interface", UVM_MEDIUM)
      memory_dpi_finalize();
    end
  endfunction

endclass

`endif