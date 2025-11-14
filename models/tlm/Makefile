# TLM Testbench Makefile
# Builds SystemC/TLM components including transactors and verification

# ============================================================================
# Configuration
# ============================================================================

SYSTEMC_HOME ?= /usr
TLM_HOME ?= /usr
C_REF_DIR := ../c_reference
BUILD_DIR := ../../build/tlm
INSTALL_DIR := ../../build

# Compiler configuration
CXX := g++
CXXFLAGS := -std=c++11 -Wall -Wextra -O2 -fPIC

# SystemC and TLM flags
SYSTEMC_CFLAGS := -I$(SYSTEMC_HOME)/include -I$(TLM_HOME)/include
SYSTEMC_LDFLAGS := -L/usr/lib/x86_64-linux-gnu -lsystemc

# C Reference Model flags
C_REF_INCLUDE := -I$(C_REF_DIR)/include
C_REF_BUILD := ../../build/c_reference
C_REF_LIB := $(C_REF_BUILD)/libmemory_model.a

# Include and source paths
INCLUDE_DIRS := -I./include $(SYSTEMC_CFLAGS) $(C_REF_INCLUDE)
SRC_DIR := ./src
SOURCES := $(wildcard $(SRC_DIR)/*.cpp)
HEADERS := $(wildcard include/*.h)
OBJECTS := $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(SOURCES))
EXECUTABLE := $(INSTALL_DIR)/tlm_testbench

# ============================================================================
# Targets
# ============================================================================

.PHONY: all clean check-env build

all: build

check-env:
@echo "Checking SystemC installation..."
@if [ ! -f "$(SYSTEMC_HOME)/include/systemc.h" ]; then \
echo "ERROR: SystemC not found at $(SYSTEMC_HOME)"; \
echo "Please install SystemC or set SYSTEMC_HOME"; \
exit 1; \
fi
@echo "SystemC found: $(SYSTEMC_HOME)"
@echo "TLM Home: $(TLM_HOME)"

$(BUILD_DIR):
@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp | $(BUILD_DIR)
@echo "Compiling $<..."
@$(CXX) $(CXXFLAGS) $(INCLUDE_DIRS) -c $< -o $@

build: check-env $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) $(C_REF_LIB) | $(INSTALL_DIR)
@echo "Linking $(EXECUTABLE)..."
@$(CXX) $(CXXFLAGS) $(OBJECTS) $(C_REF_LIB) \
$(INCLUDE_DIRS) $(SYSTEMC_LDFLAGS) -o $(EXECUTABLE)
@echo "Build successful: $(EXECUTABLE)"

$(INSTALL_DIR):
@mkdir -p $(INSTALL_DIR)

$(C_REF_LIB):
@echo "Building C reference model..."
@$(MAKE) -C ../../ c_reference

clean:
@echo "Cleaning TLM build artifacts..."
@rm -rf $(BUILD_DIR)
@rm -f $(EXECUTABLE)

help:
@echo "TLM Testbench Build System"
@echo ""
@echo "Targets:"
@echo "  all          - Build TLM testbench (default)"
@echo "  build        - Same as 'all'"
@echo "  clean        - Remove build artifacts"
@echo "  check-env    - Verify SystemC installation"
@echo "  help         - Show this help message"

.DEFAULT_GOAL := all
