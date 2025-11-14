// Basic SystemVerilog package for common definitions
// This file will be expanded with project-specific definitions

package common_pkg;
  // Time parameters
  parameter real CLOCK_PERIOD = 10.0; // ns
  parameter real SETUP_TIME   = 2.0;  // ns
  parameter real HOLD_TIME    = 1.0;  // ns
  
  // Address and data widths
  parameter int ADDR_WIDTH = 32;
  parameter int DATA_WIDTH = 64;
  
  // Common constants
  parameter int MAX_TRANS = 1024;
  
  // TODO: Add project-specific definitions
  // - Address map definitions
  // - Register offsets
  // - Command codes
  // - Status definitions
  
endpackage
