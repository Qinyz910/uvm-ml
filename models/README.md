# Models Directory

This directory contains C/C++ and SystemC models at various abstraction levels.

## Structure
```
models/
├── tlm/          # Transaction-Level Models (TLM 2.0)
├── c_models/     # Pure C/C++ reference models
├── systemc/      # SystemC implementation models
└── README.md     # This file
```

## Model Types

### TLM (Transaction-Level Models)
- High-level abstract models
- TLM 2.0 compliant interfaces
- Fast functional simulation
- Early architecture exploration

### C Models
- Reference implementations
- Bit-accurate behavioral models
- Algorithm verification
- Performance estimation

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
- [ ] Implement reference C models
- [ ] Develop SystemC behavioral models
- [ ] Set up model integration framework
- [ ] Add model validation tests
