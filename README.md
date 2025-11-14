# Hardware Verification Project

This repository contains a comprehensive hardware verification framework that integrates RTL design, SystemC/TLM modeling, and UVM-based verification components.

## Project Goals

- Provide a unified verification environment for complex digital designs
- Support multiple abstraction levels from RTL to transaction-level modeling
- Enable reusable verification components using UVM methodology
- Facilitate co-simulation between SystemVerilog and SystemC components

## Repository Structure

```
.
├── rtl/                    # Register-Transfer Level designs
│   ├── src/               # RTL source files
│   ├── include/           # Header files and packages
│   └── tb/                # Testbench components
├── verification/          # Verification environment
│   └── uvm_ml/           # UVM-ML (Multi-Language) components
│       ├── agents/       # UVM agents
│       ├── envs/         # UVM environments
│       ├── sequences/    # Test sequences
│       └── tests/        # Test cases
├── models/               # C/C++ and SystemC models
│   ├── tlm/             # Transaction-Level Models
│   ├── c_models/        # Pure C/C++ reference models
│   └── systemc/         # SystemC implementation models
├── common/              # Shared utilities and interfaces
│   ├── interfaces/      # Common interface definitions
│   ├── utils/           # Utility functions and packages
│   └── scripts/         # Build and utility scripts
├── docs/                # Documentation
│   ├── design/          # Design specifications
│   ├── verification/    # Verification plans and reports
│   └── api/             # API documentation
├── Makefile            # Build orchestration
└── README.md           # This file
```

## Toolchain Requirements

### Required Tools
- **SystemVerilog Simulator**: VCS, Questa/ModelSim, Xcelium, or equivalent
- **SystemC 2.3.3+**: IEEE 1666-2011 compliant SystemC installation
- **TLM 2.0**: Transaction-Level Modeling standard
- **UVM-ML**: Universal Verification Methodology Multi-Language support
- **C++ Compiler**: GCC 7.0+ or Clang 5.0+ with C++11 support
- **Make**: GNU Make 3.8+ or equivalent

### Optional Tools
- **Python 3.6+**: For utility scripts and automation
- **Doxygen**: For API documentation generation
- **Coverage Tools**: For code coverage analysis

## Build and Simulation

### Prerequisites Setup

1. Ensure SystemC environment variables are set:
   ```bash
   export SYSTEMC_HOME=/path/to/systemc-2.3.3
   export LD_LIBRARY_PATH=$SYSTEMC_HOME/lib-linux64:$LD_LIBRARY_PATH
   ```

2. Set UVM-ML environment:
   ```bash
   export UVM_ML_HOME=/path/to/uvm-ml
   ```

### Build Commands

```bash
# Build all components
make all

# Build individual components
make rtl          # Compile RTL designs
make models       # Build SystemC/C++ models
make verification # Compile UVM verification environment

# Clean build artifacts
make clean
make distclean   # Remove all generated files
```

### Simulation Commands

```bash
# Run basic RTL simulation
make sim-rtl

# Run SystemC model simulation
make sim-models

# Run full UVM verification
make sim-uvm

# Run co-simulation (RTL + SystemC)
make sim-cosim
```

## Verification Methodology

This project uses UVM-ML to enable:
- **Multi-language verification**: SystemVerilog UVM components with SystemC models
- **Transaction-level modeling**: High-level abstraction for early verification
- **Reusable verification IP**: Portable verification components
- **Coverage-driven verification**: Functional and code coverage metrics

## Development Workflow

1. **Design Phase**: Implement RTL designs in `rtl/` directory
2. **Model Development**: Create reference models in `models/`
3. **Verification Environment**: Develop UVM components in `verification/uvm_ml/`
4. **Integration**: Connect components through common interfaces in `common/`
5. **Validation**: Run simulations and analyze coverage

## Documentation

- Design specifications are available in `docs/design/`
- Verification plans and test results in `docs/verification/`
- API documentation generated from source comments in `docs/api/`

## Roadmap

### Phase 1: Infrastructure Setup
- [x] Basic repository structure
- [x] Build system foundation
- [ ] Basic RTL examples
- [ ] Simple SystemC models

### Phase 2: Verification Environment
- [ ] UVM-ML integration
- [ ] Basic agents and sequences
- [ ] Reference models
- [ ] Coverage collection

### Phase 3: Advanced Features
- [ ] Co-simulation framework
- [ ] Power-aware verification
- [ ] Performance analysis
- [ ] Automated regression

## Contributing

1. Follow existing directory structure and naming conventions
2. Add appropriate documentation for new components
3. Ensure all code compiles with the specified toolchain
4. Update build system when adding new components

## License

[Specify license type here]

## Contact

[Add contact information for project maintainers]
