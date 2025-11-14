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
INCLUDE_DIRS := -I./include $(SYSTEMC_CFLAGS) $(C_REF_INCLUDE) -I../../common
SRC_DIR := ./src
SOURCES := $(wildcard $(SRC_DIR)/*.cpp)
HEADERS := $(wildcard include/*.h)
OBJECTS := $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(SOURCES))
EXECUTABLE := $(INSTALL_DIR)/tlm_testbench
DPI_EXECUTABLE := $(INSTALL_DIR)/tlm_dpi_testbench

# DPI bridge sources
DPI_SOURCES := $(SRC_DIR)/tlm_dpi_testbench.cpp $(SRC_DIR)/memory_dpi_transactor.cpp
DPI_OBJECTS := $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(DPI_SOURCES))

# ============================================================================
# Targets
# ============================================================================

.PHONY: all clean check-env build build-dpi

all: build

check-env:
    @echo "Checking SystemC installation..."
    @echo "SystemC found: $(SYSTEMC_HOME)"
    @echo "TLM Home: $(TLM_HOME)"

$(BUILD_DIR):
    @mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp | $(BUILD_DIR)
    @echo "Compiling $<..."
    @$(CXX) $(CXXFLAGS) $(INCLUDE_DIRS) -c $< -o $@

build: check-env $(EXECUTABLE)

# Build DPI-enabled testbench
build-dpi: check-env $(DPI_EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) $(C_REF_LIB) | $(INSTALL_DIR)
    @echo "Linking $(EXECUTABLE)..."
    @$(CXX) $(CXXFLAGS) $(OBJECTS) $(C_REF_LIB) \
    $(INCLUDE_DIRS) $(SYSTEMC_LDFLAGS) -o $(EXECUTABLE)
    @echo "Build successful: $(EXECUTABLE)"

$(DPI_EXECUTABLE): $(DPI_OBJECTS) $(OBJECTS) $(C_REF_LIB) | $(INSTALL_DIR)
    @echo "Linking DPI-enabled $(DPI_EXECUTABLE)..."
    @$(CXX) $(CXXFLAGS) $(DPI_OBJECTS) $(OBJECTS) $(C_REF_LIB) \
    $(INCLUDE_DIRS) $(SYSTEMC_LDFLAGS) -o $(DPI_EXECUTABLE)
    @echo "DPI Build successful: $(DPI_EXECUTABLE)"

$(INSTALL_DIR):
    @mkdir -p $(INSTALL_DIR)

$(C_REF_LIB):
    @echo "Building C reference model..."
    @$(MAKE) -C ../../ c_reference

clean:
    @echo "Cleaning TLM build artifacts..."
    @rm -rf $(BUILD_DIR)
    @rm -f $(EXECUTABLE) $(DPI_EXECUTABLE)

help:
    @echo "TLM Testbench Build System"
    @echo ""
    @echo "Targets:"
    @echo "  all          - Build TLM testbench (default)"
    @echo "  build        - Same as 'all'"
    @echo "  build-dpi    - Build DPI-enabled TLM testbench"
    @echo "  clean        - Remove build artifacts"
    @echo "  check-env    - Verify SystemC installation"
    @echo "  help         - Show this help message"

.DEFAULT_GOAL := all