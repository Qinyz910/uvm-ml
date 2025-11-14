# Makefile for UVM ML Memory Verification Environment
# Supports multiple simulators: VCS, Questa, Xcelium

# Default simulator
SIM ?= questa

# Test selection
TEST ?= smoke_test

# Verbosity
VERBOSITY ?= UVM_MEDIUM

# Directories
TB_DIR = tb
AGENT_DIR = agents/mem_agent
SEQ_DIR = sequences
ENV_DIR = env
TEST_DIR = tests
WORK_DIR = work

# Source files
TB_TOP = $(TB_DIR)/testbench_top.sv
PKG_FILES = $(SEQ_DIR)/mem_sequences_pkg.sv \
            $(AGENT_DIR)/mem_agent_pkg.sv \
            $(ENV_DIR)/mem_env_pkg.sv \
            $(TEST_DIR)/mem_tests_pkg.sv

# VCS options
VCS = vcs
VCS_FLAGS = -full64 -sverilog +vcs+lic+wait \
            -timescale=1ns/1ps \
            -debug_access+all \
            +incdir+$(AGENT_DIR) \
            +incdir+$(SEQ_DIR) \
            +incdir+$(ENV_DIR) \
            +incdir+$(TEST_DIR) \
            -ntb_opts uvm-1.2

# Questa options
QUESTA = qverilog
QUESTA_FLAGS = -64 \
               +incdir+$(AGENT_DIR) \
               +incdir+$(SEQ_DIR) \
               +incdir+$(ENV_DIR) \
               +incdir+$(TEST_DIR) \
               -timescale 1ns/1ps \
               -suppress 2583

# Xcelium options
XCELIUM = xrun
XCELIUM_FLAGS = -64bit \
                +incdir+$(AGENT_DIR) \
                +incdir+$(SEQ_DIR) \
                +incdir+$(ENV_DIR) \
                +incdir+$(TEST_DIR) \
                -timescale 1ns/1ps \
                -uvm

# Run options
RUN_OPTS = +UVM_TESTNAME=$(TEST) \
           +UVM_VERBOSITY=$(VERBOSITY)

# Main targets
.PHONY: all clean compile run sim help

all: sim

help:
	@echo "UVM ML Memory Verification Environment Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make sim                    - Compile and run default test (smoke_test)"
	@echo "  make sim TEST=<test_name>   - Run specific test"
	@echo "  make compile                - Compile only"
	@echo "  make clean                  - Clean build artifacts"
	@echo ""
	@echo "Supported tests:"
	@echo "  smoke_test   - Basic functionality test"
	@echo "  stress_test  - High-volume stress test"
	@echo "  edge_test    - Edge case scenarios"
	@echo "  base_test    - Minimal base test"
	@echo ""
	@echo "Examples:"
	@echo "  make sim TEST=smoke_test"
	@echo "  make sim TEST=stress_test VERBOSITY=UVM_HIGH"
	@echo "  make sim SIM=vcs TEST=edge_test"

# Simulator-specific targets
ifeq ($(SIM),vcs)
compile:
	$(VCS) $(VCS_FLAGS) $(PKG_FILES) $(TB_TOP) -l compile.log

run: compile
	./simv $(RUN_OPTS) -l sim_$(TEST).log

sim: run
endif

ifeq ($(SIM),questa)
compile:
	@mkdir -p $(WORK_DIR)
	$(QUESTA) $(QUESTA_FLAGS) $(PKG_FILES) $(TB_TOP) -c -do "quit -f" -l compile.log

run:
	$(QUESTA) $(QUESTA_FLAGS) $(RUN_OPTS) $(PKG_FILES) $(TB_TOP) -c -do "run -all; quit -f" -l sim_$(TEST).log

sim: run
endif

ifeq ($(SIM),xcelium)
compile:
	$(XCELIUM) $(XCELIUM_FLAGS) -compile $(PKG_FILES) $(TB_TOP) -l compile.log

run: compile
	$(XCELIUM) $(XCELIUM_FLAGS) $(RUN_OPTS) -R -l sim_$(TEST).log

sim: run
endif

# Quick test targets
smoke: TEST=smoke_test
smoke: sim

stress: TEST=stress_test
stress: sim

edge: TEST=edge_test
edge: sim

# Clean target
clean:
	rm -rf simv* csrc *.log *.key *.vpd DVEfiles
	rm -rf work transcript vsim.wlf modelsim.ini
	rm -rf xcelium.d INCA_libs *.shm *.diag
	rm -rf $(WORK_DIR)
	@echo "Cleaned all build artifacts"

# Check syntax only (fast)
check:
	@echo "Syntax check not yet implemented"

# Print configuration
config:
	@echo "Configuration:"
	@echo "  Simulator: $(SIM)"
	@echo "  Test:      $(TEST)"
	@echo "  Verbosity: $(VERBOSITY)"
	@echo "  Work Dir:  $(WORK_DIR)"
