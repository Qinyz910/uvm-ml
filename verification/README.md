# Verification Directory

This directory contains the verification environment using UVM-ML (Universal Verification Methodology - Multi-Language).

## Structure
```
verification/
└── uvm_ml/       # UVM-ML components
    ├── agents/   # UVM agents (drivers, monitors, sequencers)
    ├── envs/     # UVM environments
    ├── sequences/ # Test sequences and sequence items
    ├── tests/    # Test cases and test scenarios
    └── README.md # This file
```

## UVM-ML Integration
This verification environment supports:
- Multi-language verification (SystemVerilog + SystemC)
- Transaction-level modeling
- Reusable verification IP
- Coverage-driven verification

## Guidelines
- Follow UVM methodology and best practices
- Use standard UVM phases (build_phase, connect_phase, etc.)
- Implement proper factory registration
- Include appropriate constraints for randomization

## TODO
- [ ] Create base testbench environment
- [ ] Implement agents for key interfaces
- [ ] Develop test sequences
- [ ] Set up coverage collection
- [ ] Configure UVM-ML bridge components
