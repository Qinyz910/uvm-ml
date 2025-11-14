#!/bin/bash
# Simple test runner for UVM ML environment
# This script demonstrates the environment without full simulator

set -e

echo "========================================"
echo "UVM ML Environment Structure Validation"
echo "========================================"
echo ""

echo "Checking directory structure..."
for dir in agents/mem_agent sequences env tests tb; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir/"
    else
        echo "  ✗ $dir/ (missing)"
        exit 1
    fi
done
echo ""

echo "Checking package files..."
for file in \
    "sequences/mem_sequences_pkg.sv" \
    "agents/mem_agent/mem_agent_pkg.sv" \
    "env/mem_env_pkg.sv" \
    "tests/mem_tests_pkg.sv" \
    "tb/testbench_top.sv"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        exit 1
    fi
done
echo ""

echo "Checking sequence files..."
for file in \
    "sequences/mem_transaction.svh" \
    "sequences/mem_base_sequence.svh" \
    "sequences/mem_read_sequence.svh" \
    "sequences/mem_write_sequence.svh" \
    "sequences/mem_tlb_load_sequence.svh" \
    "sequences/mem_smoke_sequence.svh" \
    "sequences/mem_stress_sequence.svh" \
    "sequences/mem_edge_sequence.svh"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        exit 1
    fi
done
echo ""

echo "Checking agent files..."
for file in \
    "agents/mem_agent/mem_config.svh" \
    "agents/mem_agent/mem_sequencer.svh" \
    "agents/mem_agent/mem_driver.svh" \
    "agents/mem_agent/mem_monitor.svh" \
    "agents/mem_agent/mem_coverage.svh" \
    "agents/mem_agent/mem_agent.svh"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        exit 1
    fi
done
echo ""

echo "Checking environment files..."
for file in \
    "env/mem_scoreboard.svh" \
    "env/mem_env.svh"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        exit 1
    fi
done
echo ""

echo "Checking test files..."
for file in \
    "tests/base_test.sv" \
    "tests/smoke_test.sv" \
    "tests/stress_test.sv" \
    "tests/edge_test.sv"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        exit 1
    fi
done
echo ""

echo "Counting lines of code..."
total_lines=0
for ext in sv svh; do
    if [ -n "$(find . -name "*.$ext" 2>/dev/null)" ]; then
        lines=$(find . -name "*.$ext" -exec cat {} \; | wc -l)
        echo "  *.$ext files: $lines lines"
        total_lines=$((total_lines + lines))
    fi
done
echo "  Total: $total_lines lines"
echo ""

echo "File statistics:"
echo "  Sequences:  $(find sequences -name "*.svh" | wc -l) files"
echo "  Agent:      $(find agents -name "*.svh" -o -name "*.sv" | wc -l) files"
echo "  Env:        $(find env -name "*.svh" -o -name "*.sv" | wc -l) files"
echo "  Tests:      $(find tests -name "*.sv" | wc -l) files"
echo "  TB:         $(find tb -name "*.sv" | wc -l) files"
echo ""

echo "========================================"
echo "✓ Structure validation PASSED"
echo "========================================"
echo ""
echo "To run simulations, you need a SystemVerilog simulator:"
echo "  make sim TEST=smoke_test    # Run smoke test"
echo "  make sim TEST=stress_test   # Run stress test"
echo "  make sim TEST=edge_test     # Run edge test"
echo ""
echo "Supported simulators: VCS, Questa, Xcelium"
echo "See README.md for detailed instructions"
