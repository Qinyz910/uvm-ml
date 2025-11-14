# Common Directory

This directory contains shared utilities, interfaces, and scripts used across the project.

## Structure
```
common/
├── interfaces/   # Common interface definitions
├── utils/        # Utility functions and packages
├── scripts/      # Build and utility scripts
└── README.md     # This file
```

## Components

### Interfaces/
- **SystemVerilog interfaces**: Shared hardware interfaces
- **TLM interfaces**: Common transaction-level interfaces
- **API definitions**: Cross-language interface specifications
- **Protocol definitions**: Communication protocols

### Utils/
- **SystemVerilog packages**: Common utilities and constants
- **C/C++ libraries**: Shared utility functions
- **Python scripts**: Automation and utility scripts
- **Configuration files**: Project-wide configuration

### Scripts/
- **Build scripts**: Additional build automation
- **Utility scripts**: File processing, conversion, etc.
- **Regression scripts**: Test automation
- **Documentation scripts**: Doc generation helpers

## Guidelines
- Keep interfaces language-agnostic where possible
- Use consistent naming conventions across languages
- Document all shared components thoroughly
- Version control all interface definitions

## Cross-Language Integration
This directory facilitates integration between:
- RTL (SystemVerilog)
- Verification (UVM-ML)
- Models (SystemC/C++)
- External tools and scripts

## TODO
- [ ] Define common interface standards
- [ ] Create utility libraries
- [ ] Develop automation scripts
- [ ] Set up configuration management
- [ ] Document integration patterns
