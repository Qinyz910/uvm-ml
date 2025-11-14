# UVM-ML Components Directory

This directory contains UVM-ML specific verification components that enable multi-language verification between SystemVerilog and SystemC.

## Directory Structure
```
uvm_ml/
├── agents/       # UVM agents for different interfaces
├── envs/         # UVM environments and testbenches
├── sequences/    # Test sequences and sequence items
├── tests/        # Test cases and scenarios
└── README.md     # This file
```

## Components Overview

### Agents/
- **driver**: Drives transactions to DUT
- **monitor**: Monitors DUT activity
- **sequencer**: Manages sequence execution
- **collector**: Collects coverage information

### Envs/
- **base_env**: Base environment with common functionality
- **full_env**: Complete environment with all agents
- **sub_envs**: Specialized sub-environments

### Sequences/
- **base_seq**: Base sequence class
- **basic_seq**: Basic functionality tests
- **stress_seq**: Stress and performance tests
- **error_seq**: Error injection tests

### Tests/
- **base_test**: Base test class
- **smoke_test**: Basic functionality test
- **regression_test**: Full regression test suite

## UVM-ML Bridge Configuration
The UVM-ML bridge enables communication between:
- SystemVerilog UVM components
- SystemC TLM models
- C/C++ reference models

## TODO
- [ ] Implement UVM-ML bridge setup
- [ ] Create base agent classes
- [ ] Develop sequence libraries
- [ ] Set up test infrastructure
- [ ] Configure multi-language communication
