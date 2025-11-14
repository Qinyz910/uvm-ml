# Hardware Verification Project Makefile
# Supports RTL, SystemC/TLM, and UVM-ML compilation and simulation

# ============================================================================
# Configuration
# ============================================================================

# Project directories
RTL_DIR       := rtl
MODELS_DIR    := models
VERIF_DIR     := verification
COMMON_DIR    := common
DOCS_DIR      := docs
BUILD_DIR     := build
SIM_DIR       := simulation

# Tool configuration (customize based on your environment)
# SystemVerilog Simulator choices: vcs, questa, xcelium
SIMULATOR     := vcs
SYSTEMC_HOME  ?= /opt/systemc
UVM_ML_HOME   ?= /opt/uvm-ml

# Compiler flags
CXX           := g++
CXXFLAGS      := -std=c++11 -Wall -Wextra -O2
SYSTEMC_FLAGS := -I$(SYSTEMC_HOME)/include -L$(SYSTEMC_HOME)/lib-linux64 -lsystemc
UVM_ML_FLAGS  := -I$(UVM_ML_HOME)/include

# Simulation flags
SIM_FLAGS     := -timescale=1ns/1ps
VCS_FLAGS     := -sverilog +v2k -timescale=1ns/1ps
QUESTA_FLAGS  := -sv -timescale 1ns/1ps
XCELIUM_FLAGS := -sv -timescale 1ns/1ps

# Source patterns
RTL_SOURCES   := $(shell find $(RTL_DIR) -name "*.sv" -o -name "*.v" 2>/dev/null)
SYSTEMC_SOURCES := $(shell find $(MODELS_DIR) -name "*.cpp" -o -name "*.cc" 2>/dev/null)
UVM_SOURCES   := $(shell find $(VERIF_DIR) -name "*.sv" -o -name "*.svh" 2>/dev/null)

# ============================================================================
# Directory Structure Setup
# ============================================================================

# Create necessary directories
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/rtl
	@mkdir -p $(BUILD_DIR)/models
	@mkdir -p $(BUILD_DIR)/verification
	@mkdir -p $(BUILD_DIR)/common

$(SIM_DIR):
	@mkdir -p $(SIM_DIR)

# ============================================================================
# RTL Compilation
# ============================================================================

.PHONY: rtl rtl-clean
rtl: $(BUILD_DIR)
	@echo "Compiling RTL designs..."
	@if [ "$(SIMULATOR)" = "vcs" ]; then \
		echo "Using VCS compiler..."; \
		vcs $(VCS_FLAGS) $(RTL_SOURCES) -o $(BUILD_DIR)/rtl/simv; \
	elif [ "$(SIMULATOR)" = "questa" ]; then \
		echo "Using Questa/ModelSim compiler..."; \
		vlib work; \
		vlog $(QUESTA_FLAGS) $(RTL_SOURCES); \
	elif [ "$(SIMULATOR)" = "xcelium" ]; then \
		echo "Using Xcelium compiler..."; \
		xmvlog $(XCELIUM_FLAGS) $(RTL_SOURCES); \
		xmelab -o $(BUILD_DIR)/rtl/xrun work.*; \
	else \
		echo "Error: Unsupported simulator $(SIMULATOR)"; \
		exit 1; \
	fi
	@echo "RTL compilation completed."

rtl-clean:
	@echo "Cleaning RTL build artifacts..."
	@rm -rf $(BUILD_DIR)/rtl
	@rm -rf work/
	@rm -f *.vvp *.vcd *.vpd *.wlf

# ============================================================================
# SystemC/TLM Models Compilation
# ============================================================================

.PHONY: models models-clean
models: $(BUILD_DIR)
	@echo "Building SystemC/TLM models..."
	@if [ -z "$(SYSTEMC_HOME)" ]; then \
		echo "Error: SYSTEMC_HOME environment variable not set"; \
		exit 1; \
	fi
	@for src in $(SYSTEMC_SOURCES); do \
		echo "Compiling $$src..."; \
		$(CXX) $(CXXFLAGS) $(SYSTEMC_FLAGS) -I$(COMMON_DIR) \
			-c $$src -o $(BUILD_DIR)/models/$$(basename $$src .cpp).o; \
	done
	@echo "Linking SystemC models..."
	$(CXX) $(CXXFLAGS) $(SYSTEMC_FLAGS) \
		$(BUILD_DIR)/models/*.o -o $(BUILD_DIR)/models/systemc_models
	@echo "SystemC models compilation completed."

models-clean:
	@echo "Cleaning SystemC models build artifacts..."
	@rm -rf $(BUILD_DIR)/models
	@rm -f *.so *.dylib *.dll

# ============================================================================
# UVM-ML Verification Environment
# ============================================================================

.PHONY: verification verification-clean
verification: $(BUILD_DIR)
	@echo "Building UVM-ML verification environment..."
	@if [ -z "$(UVM_ML_HOME)" ]; then \
		echo "Warning: UVM_ML_HOME not set, using default UVM"; \
	fi
	@if [ "$(SIMULATOR)" = "vcs" ]; then \
		echo "Compiling UVM with VCS..."; \
		vcs $(VCS_FLAGS) $(UVM_SOURCES) $(RTL_SOURCES) \
			-o $(BUILD_DIR)/verification/uvm_simv; \
	elif [ "$(SIMULATOR)" = "questa" ]; then \
		echo "Compiling UVM with Questa..."; \
		vlib work; \
		vlog $(QUESTA_FLAGS) $(UVM_SOURCES) $(RTL_SOURCES); \
	elif [ "$(SIMULATOR)" = "xcelium" ]; then \
		echo "Compiling UVM with Xcelium..."; \
		xmvlog $(XCELIUM_FLAGS) $(UVM_SOURCES) $(RTL_SOURCES); \
		xmelab -o $(BUILD_DIR)/verification/uvm_xrun work.*; \
	fi
	@echo "UML verification environment compilation completed."

verification-clean:
	@echo "Cleaning UVM verification build artifacts..."
	@rm -rf $(BUILD_DIR)/verification
	@rm -rf work/

# ============================================================================
# Simulation Targets
# ============================================================================

.PHONY: sim-rtl sim-models sim-uvm sim-cosim
sim-rtl: rtl $(SIM_DIR)
	@echo "Running RTL simulation..."
	@if [ "$(SIMULATOR)" = "vcs" ]; then \
		cd $(SIM_DIR) && $(BUILD_DIR)/rtl/simv $(SIM_FLAGS); \
	elif [ "$(SIMULATOR)" = "questa" ]; then \
		cd $(SIM_DIR) && vsim -c -do "run -all; quit" work.top; \
	elif [ "$(SIMULATOR)" = "xcelium" ]; then \
		cd $(SIM_DIR) && $(BUILD_DIR)/rtl/xrun $(SIM_FLAGS); \
	fi

sim-models: models $(SIM_DIR)
	@echo "Running SystemC models simulation..."
	@cd $(SIM_DIR) && $(BUILD_DIR)/models/systemc_models

sim-uvm: verification $(SIM_DIR)
	@echo "Running UVM verification..."
	@if [ "$(SIMULATOR)" = "vcs" ]; then \
		cd $(SIM_DIR) && $(BUILD_DIR)/verification/uvm_simv +UVM_TESTNAME=base_test; \
	elif [ "$(SIMULATOR)" = "questa" ]; then \
		cd $(SIM_DIR) && vsim -c -do "run -all; quit" work.uvm_testbench +UVM_TESTNAME=base_test; \
	elif [ "$(SIMULATOR)" = "xcelium" ]; then \
		cd $(SIM_DIR) && $(BUILD_DIR)/verification/uvm_xrun +UVM_TESTNAME=base_test; \
	fi

sim-cosim: rtl models verification $(SIM_DIR)
	@echo "Running co-simulation (RTL + SystemC + UVM)..."
	@echo "Co-simulation setup required - implement based on specific toolchain"

# ============================================================================
# Documentation
# ============================================================================

.PHONY: docs docs-clean
docs:
	@echo "Generating documentation..."
	@if command -v doxygen >/dev/null 2>&1; then \
		doxygen Doxyfile; \
	else \
		echo "Doxygen not found. Install doxygen for API documentation."; \
	fi

docs-clean:
	@echo "Cleaning documentation..."
	@rm -rf $(DOCS_DIR)/_build/
	@rm -rf $(DOCS_DIR)/build/

# ============================================================================
# Utility Targets
# ============================================================================

.PHONY: all clean distclean help check-env list-sources

all: rtl models verification

clean: rtl-clean models-clean verification-clean
	@echo "Cleaning all build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(SIM_DIR)

distclean: clean docs-clean
	@echo "Deep cleaning..."
	@rm -f *.log *.wlf *.vcd *.vpd *.fsdb
	@rm -f *.daidir *.csrc *.vcs.key *.ucli.key
	@rm -rf urgReport/ DVEfiles/

help:
	@echo "Hardware Verification Project Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  rtl          - Compile RTL designs"
	@echo "  models       - Build SystemC/TLM models"
	@echo "  verification - Build UVM-ML verification environment"
	@echo "  sim-rtl      - Run RTL simulation"
	@echo "  sim-models   - Run SystemC models simulation"
	@echo "  sim-uvm      - Run UVM verification"
	@echo "  sim-cosim    - Run co-simulation (RTL + SystemC + UVM)"
	@echo "  docs         - Generate documentation"
	@echo "  all          - Build all components (default)"
	@echo "  clean        - Remove build artifacts"
	@echo "  distclean    - Deep clean all generated files"
	@echo "  check-env    - Verify environment setup"
	@echo "  list-sources - List all source files"
	@echo "  help         - Show this help message"

check-env:
	@echo "Checking environment setup..."
	@echo "Simulator: $(SIMULATOR)"
	@echo "SystemC Home: $(SYSTEMC_HOME)"
	@echo "UVM-ML Home: $(UVM_ML_HOME)"
	@if [ -z "$(SYSTEMC_HOME)" ]; then \
		echo "Warning: SYSTEMC_HOME not set"; \
	fi
	@if [ -z "$(UVM_ML_HOME)" ]; then \
		echo "Warning: UVM_ML_HOME not set"; \
	fi
	@if command -v $(CXX) >/dev/null 2>&1; then \
		echo "C++ Compiler: $$($(CXX) --version | head -n1)"; \
	else \
		echo "Error: C++ compiler not found"; \
	fi

list-sources:
	@echo "RTL Sources:"
	@if [ -n "$(RTL_SOURCES)" ]; then \
		for src in $(RTL_SOURCES); do echo "  $$src"; done; \
	else \
		echo "  No RTL sources found"; \
	fi
	@echo ""
	@echo "SystemC Sources:"
	@if [ -n "$(SYSTEMC_SOURCES)" ]; then \
		for src in $(SYSTEMC_SOURCES); do echo "  $$src"; done; \
	else \
		echo "  No SystemC sources found"; \
	fi
	@echo ""
	@echo "UVM Sources:"
	@if [ -n "$(UVM_SOURCES)" ]; then \
		for src in $(UVM_SOURCES); do echo "  $$src"; done; \
	else \
		echo "  No UVM sources found"; \
	fi

# Default target
.DEFAULT_GOAL := all
