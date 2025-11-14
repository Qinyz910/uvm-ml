#!/bin/bash

# Quick Test Script - Basic verification flow validation
# Tests the end-to-end integration with minimal setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test 1: Build C reference model
test_c_reference() {
    print_status "Building C reference model..."
    cd "$PROJECT_ROOT"
    if make c_reference > /dev/null 2>&1; then
        print_success "C reference model builds and tests pass"
        return 0
    else
        print_error "C reference model failed"
        return 1
    fi
}

# Test 2: Build TLM components
test_tlm() {
    print_status "Building TLM components..."
    cd "$PROJECT_ROOT/models/tlm"
    if make clean && make all > /dev/null 2>&1; then
        print_success "TLM components build successfully"
        return 0
    else
        print_error "TLM build failed"
        return 1
    fi
}

# Test 3: Build UVM environment
test_uvm() {
    print_status "Building UVM verification environment..."
    cd "$PROJECT_ROOT"
    if make verification > /dev/null 2>&1; then
        print_success "UVM environment builds successfully"
        return 0
    else
        print_error "UVM build failed"
        return 1
    fi
}

# Test 4: Run basic smoke test
test_smoke() {
    print_status "Running basic smoke test..."
    cd "$PROJECT_ROOT/simulation"
    if timeout 30s ../build/verification/uvm_simv +UVM_TESTNAME=smoke_test +UVM_VERBOSITY=UVM_LOW > quick_test.log 2>&1; then
        if grep -q "PASS" quick_test.log 2>/dev/null; then
            print_success "Smoke test passes"
            return 0
        else
            print_error "Smoke test failed - check quick_test.log"
            return 1
        fi
    else
        print_error "Smoke test timed out or crashed"
        return 1
    fi
}

# Test 5: Check DPI interface compilation
test_dpi() {
    print_status "Checking DPI interface compilation..."
    cd "$PROJECT_ROOT/common"
    if gcc -c memory_dpi.c -o memory_dpi.o > /dev/null 2>&1; then
        print_success "DPI interface compiles"
        rm -f memory_dpi.o
        return 0
    else
        print_error "DPI interface compilation failed"
        return 1
    fi
}

# Main test execution
main() {
    echo "========================================"
    echo "Memory Verification Quick Test Suite"
    echo "========================================"
    
    local tests_passed=0
    local total_tests=5
    
    test_c_reference && ((tests_passed++))
    test_tlm && ((tests_passed++))
    test_uvm && ((tests_passed++))
    test_smoke && ((tests_passed++))
    test_dpi && ((tests_passed++))
    
    echo "========================================"
    echo "Test Results: $tests_passed/$total_tests passed"
    echo "========================================"
    
    if [ $tests_passed -eq $total_tests ]; then
        print_success "All quick tests passed!"
        echo "The verification flow is ready for full regression."
        exit 0
    else
        print_error "Some tests failed. Check the build and fix issues."
        exit 1
    fi
}

main "$@"