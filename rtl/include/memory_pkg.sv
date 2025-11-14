// Memory module package definition
// Includes parameters, structures, and utility functions for the Memory RTL module

package memory_pkg;

  // Default parameters
  parameter int VIRT_ADDR_WIDTH = 32;  // Virtual address width
  parameter int PHYS_ADDR_WIDTH = 28;  // Physical address width
  parameter int MEM_DEPTH = 16384;     // Memory depth (in data words)
  parameter int PAGE_SIZE = 4096;      // Page size (bytes)
  parameter int DATA_WIDTH = 64;       // Data width (bits)
  parameter int PT_ENTRIES = 256;      // Page table entries

  // Control commands
  typedef enum logic [3:0] {
    MEM_READ    = 4'h0,
    MEM_WRITE   = 4'h1,
    MEM_FLUSH   = 4'h2,
    MEM_TLB_LD  = 4'h3
  } mem_command_e;

  // Response status codes
  typedef enum logic [3:0] {
    MEM_OK          = 4'h0,
    MEM_ERR_ADDR    = 4'h1,  // Address translation error
    MEM_ERR_ACCESS  = 4'h2,  // Access violation
    MEM_ERR_WRITE   = 4'h3,  // Write error
    MEM_PENDING     = 4'hF   // Pending/busy
  } mem_status_e;

  // Translation table entry structure
  typedef struct packed {
    logic valid;
    logic [PHYS_ADDR_WIDTH-1:0] phys_base;
    logic [VIRT_ADDR_WIDTH-1:0] virt_base;
  } tlb_entry_t;

  // Read request structure
  typedef struct packed {
    logic valid;
    logic [VIRT_ADDR_WIDTH-1:0] virt_addr;
    logic [(DATA_WIDTH/8)-1:0] data_mask;
  } read_req_t;

  // Write request structure
  typedef struct packed {
    logic valid;
    logic [VIRT_ADDR_WIDTH-1:0] virt_addr;
    logic [(DATA_WIDTH/8)-1:0] data_mask;
    logic [DATA_WIDTH-1:0] data;
  } write_req_t;

  // Read response structure
  typedef struct packed {
    logic valid;
    mem_status_e status;
    logic [DATA_WIDTH-1:0] data;
  } read_resp_t;

  // Write response structure
  typedef struct packed {
    logic valid;
    mem_status_e status;
  } write_resp_t;

endpackage

