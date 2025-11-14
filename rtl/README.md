# RTL (Register-Transfer Level) Directory

This directory contains all RTL design files and related components.

## Structure
```
rtl/
├── src/           # RTL source files (.sv, .v)
├── include/       # Header files, packages, and interfaces
├── tb/           # Testbench components
└── README.md     # This file
```

## Guidelines
- Use SystemVerilog for new designs
- Follow naming conventions: lowercase with underscores for signals
- Include appropriate comments and documentation
- Use packages for shared definitions and utilities

## File Naming
- Module files: `<module_name>.sv`
- Package files: `<package_name>_pkg.sv`
- Interface files: `<interface_name>_if.sv`
- Testbench files: `<dut>_tb.sv`

## TODO
- [ ] Add RTL source files
- [ ] Create package definitions
- [ ] Define interfaces
- [ ] Implement testbench components
