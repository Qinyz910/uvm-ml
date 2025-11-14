#!/bin/bash

# Memory Verification Regression Script
# Runs smoke, directed, and random tests with comprehensive reporting

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
SIM_DIR="$PROJECT_ROOT/simulation"
REGRESSION_DIR="$SIM_DIR/regression"
LOG_DIR="$REGRESSION_DIR/logs"
REPORT_FILE="$REGRESSION_DIR/regression_report.txt"

# Test configuration
SIMULATOR=${SIMULATOR:-"vcs"}
ENABLE_WAVES=${ENABLE_WAVES:-"0"}
ENABLE_COVERAGE=${ENABLE_COVERAGE:-"1"}
SEED=${SEED:-"1"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Setup directories
setup_directories() {
    print_header "Setting up directories"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$SIM_DIR"
    mkdir -p "$REGRESSION_DIR"
    mkdir -p "$LOG_DIR"
    print_success "Directories created"
}

# Build all components
build_components() {
    print_header "Building verification components"
    
    cd "$PROJECT_ROOT"
    
    # Build C reference model
    echo "Building C reference model..."
    if make c_reference > "$LOG_DIR/c_ref_build.log" 2>&1; then
        print_success "C reference model built"
    else
        print_error "C reference model build failed"
        tail -20 "$LOG_DIR/c_ref_build.log"
        return 1
    fi
    
    # Build TLM components
    echo "Building TLM components..."
    cd models/tlm
    if make clean && make all > "$LOG_DIR/tlm_build.log" 2>&1; then
        print_success "TLM components built"
    else
        print_error "TLM build failed"
        tail -20 "$LOG_DIR/tlm_build.log"
        return 1
    fi
    cd "$PROJECT_ROOT"
    
    # Build UVM verification environment
    echo "Building UVM verification environment..."
    if make verification > "$LOG_DIR/uvm_build.log" 2>&1; then
        print_success "UVM verification environment built"
    else
        print_error "UVM build failed"
        tail -20 "$LOG_DIR/uvm_build.log"
        return 1
    fi
    
    print_success "All components built successfully"
}

# Run individual test
run_test() {
    local test_name="$1"
    local test_type="$2"
    local extra_args="$3"
    
    echo "Running $test_type test: $test_name..."
    
    local log_file="$LOG_DIR/${test_name}.log"
    local waves_arg=""
    local coverage_arg=""
    
    if [ "$ENABLE_WAVES" = "1" ]; then
        waves_arg="+WAVES=vcd"
    fi
    
    if [ "$ENABLE_COVERAGE" = "1" ]; then
        coverage_arg="+UVM_COVERAGE=1"
    fi
    
    cd "$SIM_DIR"
    
    # Set seed for reproducibility
    export UVM_TEST_SEED="$SEED"
    
    # Run the test
    timeout 300s "$BUILD_DIR/verification/uvm_simv" \
        +UVM_TESTNAME="$test_name" \
        +UVM_VERBOSITY=UVM_MEDIUM \
        $waves_arg \
        $coverage_arg \
        $extra_args \
        > "$log_file" 2>&1
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Check for UVM test completion
        if grep -q "UVM_INFO.*UVM_TEST" "$log_file" && \
           grep -q "UVM_INFO.*REPORT" "$log_file"; then
            print_success "$test_name PASSED"
            echo "$test_name,PASS,$test_type" >> "$REPORT_FILE"
            return 0
        else
            print_error "$test_name FAILED (incomplete UVM execution)"
            echo "$test_name,FAIL,$test_type" >> "$REPORT_FILE"
            return 1
        fi
    elif [ $exit_code -eq 124 ]; then
        print_error "$test_name TIMEOUT"
        echo "$test_name,TIMEOUT,$test_type" >> "$REPORT_FILE"
        return 1
    else
        print_error "$test_name FAILED (exit code: $exit_code)"
        echo "$test_name,FAIL,$test_type" >> "$REPORT_FILE"
        return 1
    fi
}

# Run smoke tests
run_smoke_tests() {
    print_header "Running Smoke Tests"
    
    # Basic functionality tests
    run_test "smoke_test" "smoke" "+UVM_TIMEOUT_NS=10000000"
    
    # Test with different seeds
    local original_seed="$SEED"
    for seed in 42 123 999; do
        SEED="$seed"
        run_test "smoke_test" "smoke" "+UVM_TIMEOUT_NS=10000000"
    done
    SEED="$original_seed"
}

# Run directed tests
run_directed_tests() {
    print_header "Running Directed Tests"
    
    # Edge case tests
    run_test "edge_test" "directed" "+UVM_TIMEOUT_NS=15000000"
    
    # TLB boundary tests
    run_test "edge_test" "directed" "+UVM_TIMEOUT_NS=15000000 +UVM_TLB_BOUNDARY=1"
    
    # Address boundary tests
    run_test "edge_test" "directed" "+UVM_TIMEOUT_NS=15000000 +UVM_ADDR_BOUNDARY=1"
}

# Run random tests
run_random_tests() {
    print_header "Running Random Tests"
    
    # Stress tests with different seeds
    local original_seed="$SEED"
    for seed in 1 100 500 1000 5000; do
        SEED="$seed"
        run_test "stress_test" "random" "+UVM_TIMEOUT_NS=30000000 +UVM_RANDOM_SEQ=1"
    done
    SEED="$original_seed"
    
    # Long duration random test
    run_test "stress_test" "random" "+UVM_TIMEOUT_NS=60000000 +UVM_RANDOM_SEQ=1 +UVM_LONG_RUN=1"
}

# Run TLM-DPI integration tests
run_integration_tests() {
    print_header "Running Integration Tests"
    
    cd "$PROJECT_ROOT/models/tlm"
    
    echo "Running TLM-DPI integration test..."
    if timeout 120s ./../../build/tlm_testbench > "$LOG_DIR/tlm_dpi_test.log" 2>&1; then
        if grep -q "Overall Result: PASS" "$LOG_DIR/tlm_dpi_test.log"; then
            print_success "TLM-DPI integration test PASSED"
            echo "tlm_dpi_test,PASS,integration" >> "$REPORT_FILE"
        else
            print_error "TLM-DPI integration test FAILED"
            echo "tlm_dpi_test,FAIL,integration" >> "$REPORT_FILE"
        fi
    else
        print_error "TLM-DPI integration test TIMEOUT or FAILED"
        echo "tlm_dpi_test,TIMEOUT,integration" >> "$REPORT_FILE"
    fi
    
    cd "$PROJECT_ROOT"
}

# Generate comprehensive report
generate_report() {
    print_header "Generating Regression Report"
    
    local total_tests=$(wc -l < "$REPORT_FILE")
    local passed_tests=$(grep -c ",PASS" "$REPORT_FILE")
    local failed_tests=$(grep -c ",FAIL" "$REPORT_FILE")
    local timeout_tests=$(grep -c ",TIMEOUT" "$REPORT_FILE")
    
    cat > "$REGRESSION_DIR/regression_summary.txt" << EOF
Memory Verification Regression Summary
========================================
Date: $(date)
Simulator: $SIMULATOR
Seed: $SEED
Waves: $ENABLE_WAVES
Coverage: $ENABLE_COVERAGE

Test Results:
------------
Total Tests: $total_tests
Passed: $passed_tests
Failed: $failed_tests
Timeout: $timeout_tests
Success Rate: $(echo "scale=2; $passed_tests * 100 / $total_tests" | bc -l)%

Test Breakdown:
---------------
EOF
    
    # Add breakdown by test type
    echo "Smoke Tests:" >> "$REGRESSION_DIR/regression_summary.txt"
    grep ",smoke" "$REPORT_FILE" | cut -d',' -f1,2 | sed 's/,/ - /' >> "$REGRESSION_DIR/regression_summary.txt"
    
    echo -e "\nDirected Tests:" >> "$REGRESSION_DIR/regression_summary.txt"
    grep ",directed" "$REPORT_FILE" | cut -d',' -f1,2 | sed 's/,/ - /' >> "$REGRESSION_DIR/regression_summary.txt"
    
    echo -e "\nRandom Tests:" >> "$REGRESSION_DIR/regression_summary.txt"
    grep ",random" "$REPORT_FILE" | cut -d',' -f1,2 | sed 's/,/ - /' >> "$REGRESSION_DIR/regression_summary.txt"
    
    echo -e "\nIntegration Tests:" >> "$REGRESSION_DIR/regression_summary.txt"
    grep ",integration" "$REPORT_FILE" | cut -d',' -f1,2 | sed 's/,/ - /' >> "$REGRESSION_DIR/regression_summary.txt"
    
    # Add coverage information if available
    if [ "$ENABLE_COVERAGE" = "1" ]; then
        echo -e "\nCoverage Information:" >> "$REGRESSION_DIR/regression_summary.txt"
        find "$LOG_DIR" -name "*.log" -exec grep -l "Coverage:" {} \; | while read log; do
            echo "From $(basename "$log"):" >> "$REGRESSION_DIR/regression_summary.txt"
            grep "Coverage:" "$log" | tail -3 >> "$REGRESSION_DIR/regression_summary.txt"
        done
    fi
    
    # Display summary
    cat "$REGRESSION_DIR/regression_summary.txt"
    
    # Final verdict
    if [ $failed_tests -eq 0 ] && [ $timeout_tests -eq 0 ]; then
        print_success "ALL TESTS PASSED - Regression SUCCESSFUL"
        return 0
    else
        print_error "Some tests failed - Regression FAILED"
        return 1
    fi
}

# Main execution
main() {
    print_header "Memory Verification Regression"
    echo "Starting regression at $(date)"
    echo "Project root: $PROJECT_ROOT"
    echo "Simulator: $SIMULATOR"
    echo "Seed: $SEED"
    
    # Initialize report file
    echo "test_name,result,test_type" > "$REPORT_FILE"
    
    # Run regression phases
    setup_directories
    build_components
    run_smoke_tests
    run_directed_tests
    run_random_tests
    run_integration_tests
    
    # Generate final report
    local final_result=$?
    generate_report
    final_result=$?
    
    echo "Regression completed at $(date)"
    exit $final_result
}

# Help function
show_help() {
    cat << EOF
Memory Verification Regression Script

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -s, --simulator TOOL    Set simulator (vcs, questa, xcelium) [default: vcs]
  -w, --waves             Enable waveform generation
  -c, --coverage          Enable coverage collection
  -r, --seed SEED         Set random seed [default: 1]
  -t, --test-type TYPE    Run only specific test type (smoke|directed|random|integration)
  --smoke-only            Run only smoke tests
  --directed-only         Run only directed tests
  --random-only           Run only random tests
  --integration-only      Run only integration tests

Examples:
  $0                      # Run full regression
  $0 -s questa -w         # Run with Questa and waves enabled
  $0 --smoke-only         # Run only smoke tests
  $0 -r 42 --random-only  # Run random tests with seed 42

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--simulator)
            SIMULATOR="$2"
            shift 2
            ;;
        -w|--waves)
            ENABLE_WAVES="1"
            shift
            ;;
        -c|--coverage)
            ENABLE_COVERAGE="1"
            shift
            ;;
        -r|--seed)
            SEED="$2"
            shift 2
            ;;
        -t|--test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        --smoke-only)
            TEST_TYPE="smoke"
            shift
            ;;
        --directed-only)
            TEST_TYPE="directed"
            shift
            ;;
        --random-only)
            TEST_TYPE="random"
            shift
            ;;
        --integration-only)
            TEST_TYPE="integration"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run specific test type if requested
if [ -n "$TEST_TYPE" ]; then
    print_header "Running $TEST_TYPE tests only"
    setup_directories
    build_components
    
    case $TEST_TYPE in
        smoke)
            run_smoke_tests
            ;;
        directed)
            run_directed_tests
            ;;
        random)
            run_random_tests
            ;;
        integration)
            run_integration_tests
            ;;
        *)
            echo "Unknown test type: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    generate_report
    exit $?
fi

# Run full regression if no specific test type requested
main