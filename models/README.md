# Models Directory

This directory contains C/C++ and SystemC models at various abstraction levels.

## Structure
```
models/
├── c_reference/  # Pure C reference models and unit tests
├── tlm/          # Transaction-Level Models (TLM 2.0)
├── systemc/      # SystemC implementation models
└── README.md     # This file
```

## Model Types

### TLM (Transaction-Level Models)
- High-level abstract models
- TLM 2.0 compliant interfaces
- Fast functional simulation
- Early architecture exploration

### C Reference Models (c_reference/)
- Bit-accurate reference implementations in portable C
- Host-friendly APIs for algorithm and RTL parity validation
- Includes standalone regression tests runnable via `make c_reference`

### SystemC Models
- Cycle-accurate models
- Hardware-software co-design
- Interface compatibility
- Timing-accurate simulation

## Guidelines
- Follow TLM 2.0 standard for transaction-level models
- Use appropriate abstraction level for accuracy vs. performance
- Include proper documentation and comments
- Implement standard SystemC coding guidelines

## Build Requirements
- SystemC 2.3.3+ installation
- TLM 2.0 headers
- C++11 compliant compiler
- Proper Makefile configuration

## TODO
- [ ] Create TLM 2.0 base models
- [x] Implement reference C models
- [ ] Develop SystemC behavioral models
- [ ] Set up model integration framework
- [ ] Add model validation tests
