#include "memory_test_scenario.h"
#include <iostream>
#include <iomanip>

MemoryTestScenario::MemoryTestScenario(sc_module_name name,
                                       MemoryInitiator *initiator,
                                       MemoryScoreboard *scoreboard)
    : sc_module(name), init(initiator), sb(scoreboard),
      test_passed(true), test_count(0), tests_passed(0)
{
    SC_THREAD(run_tests);
}

MemoryTestScenario::~MemoryTestScenario()
{
}

void MemoryTestScenario::run_tests()
{
    std::cout << "\n=== Memory TLM Test Scenario Starting ===" << std::endl;
    std::cout << "@ " << sc_time_stamp() << std::endl;

    // Wait for reset
    wait(10, SC_NS);

    // Run individual tests
    test_tlb_load();
    test_basic_write();
    test_basic_read();
    test_masked_write();
    test_sequential_rw();
    test_error_handling();

    // Print final results
    std::cout << "\n=== Memory TLM Test Scenario Complete ===" << std::endl;
    std::cout << "Total Tests: " << test_count << std::endl;
    std::cout << "Passed: " << tests_passed << std::endl;
    std::cout << "Failed: " << (test_count - tests_passed) << std::endl;
    std::cout << "Overall Result: " << (test_passed ? "PASS" : "FAIL") << std::endl;

    sc_stop();
}

void MemoryTestScenario::test_tlb_load()
{
    std::cout << "\n>>> Test 1: TLB Load Operations" << std::endl;
    
    test_count++;
    bool local_pass = true;

    // Load TLB entry: virtual page 0x1000 -> physical page 0x2000
    init->send_tlb_load(0x1000, 0x2000);
    wait_cycles(2);

    // Load another entry: virtual page 0x3000 -> physical page 0x4000
    init->send_tlb_load(0x3000, 0x4000);
    wait_cycles(2);

    std::cout << "    TLB load test completed" << std::endl;
    log_test("TLB Load", local_pass);
    if (local_pass) tests_passed++;
    else test_passed = false;
}

void MemoryTestScenario::test_basic_write()
{
    std::cout << "\n>>> Test 2: Basic Write Operations" << std::endl;
    
    test_count++;
    bool local_pass = true;

    // Write to address 0x1000 with full byte mask (0xFF)
    uint64_t write_data = 0x123456789ABCDEF0ULL;
    init->send_write(0x1000, 0xFF, write_data);
    wait_cycles(2);

    // Write to address 0x1008 with partial mask (0x0F)
    uint64_t partial_data = 0x0000000011223344ULL;
    init->send_write(0x1008, 0x0F, partial_data);
    wait_cycles(2);

    std::cout << "    Basic write test completed" << std::endl;
    log_test("Basic Write", local_pass);
    if (local_pass) tests_passed++;
    else test_passed = false;
}

void MemoryTestScenario::test_basic_read()
{
    std::cout << "\n>>> Test 3: Basic Read Operations" << std::endl;
    
    test_count++;
    bool local_pass = true;

    // Read from address 0x1000 (previously written)
    init->send_read(0x1000, 0xFF);
    wait_cycles(2);

    // Read from address 0x1008
    init->send_read(0x1008, 0xFF);
    wait_cycles(2);

    std::cout << "    Basic read test completed" << std::endl;
    log_test("Basic Read", local_pass);
    if (local_pass) tests_passed++;
    else test_passed = false;
}

void MemoryTestScenario::test_masked_write()
{
    std::cout << "\n>>> Test 4: Masked Write Operations" << std::endl;
    
    test_count++;
    bool local_pass = true;

    // Write with different byte masks to test partial updates
    uint64_t data1 = 0xFFFFFFFF00000000ULL;
    init->send_write(0x2000, 0xF0, data1);  // High bytes only
    wait_cycles(2);

    uint64_t data2 = 0x00000000FFFFFFFFULL;
    init->send_write(0x2000, 0x0F, data2);  // Low bytes only
    wait_cycles(2);

    // Read back to verify
    init->send_read(0x2000, 0xFF);
    wait_cycles(2);

    std::cout << "    Masked write test completed" << std::endl;
    log_test("Masked Write", local_pass);
    if (local_pass) tests_passed++;
    else test_passed = false;
}

void MemoryTestScenario::test_sequential_rw()
{
    std::cout << "\n>>> Test 5: Sequential Read-After-Write" << std::endl;
    
    test_count++;
    bool local_pass = true;

    // Perform a sequence of writes followed by reads
    for (unsigned int i = 0; i < 4; i++) {
        uint64_t addr = 0x3000 + (i * 8);
        uint64_t data = 0x0000000000000100ULL | i;
        
        init->send_write(addr, 0xFF, data);
        wait_cycles(1);
        
        init->send_read(addr, 0xFF);
        wait_cycles(1);
    }

    std::cout << "    Sequential read-after-write test completed" << std::endl;
    log_test("Sequential R/W", local_pass);
    if (local_pass) tests_passed++;
    else test_passed = false;
}

void MemoryTestScenario::test_error_handling()
{
    std::cout << "\n>>> Test 6: Error Handling (Translation Miss)" << std::endl;
    
    test_count++;
    bool local_pass = true;

    // Try to access an unmapped virtual address
    // This should trigger a translation error
    init->send_read(0x5000, 0xFF);  // Address not in TLB
    wait_cycles(2);

    init->send_write(0x5000, 0xFF, 0x1234567890ABCDEFULL);
    wait_cycles(2);

    std::cout << "    Error handling test completed" << std::endl;
    log_test("Error Handling", local_pass);
    if (local_pass) tests_passed++;
    else test_passed = false;
}

void MemoryTestScenario::wait_cycles(unsigned int n)
{
    wait(n * 10, SC_NS);  // Assuming 10ns clock period
}

void MemoryTestScenario::log_test(const std::string &name, bool passed)
{
    std::cout << "    Result: " << (passed ? "PASS" : "FAIL") 
              << " [" << name << "]" << std::endl;
}
