#ifndef MEMORY_TEST_SCENARIO_H
#define MEMORY_TEST_SCENARIO_H

#include "systemc.h"
#include "tlm_transaction.h"
#include "memory_transactor.h"
#include "memory_scoreboard.h"

/**
 * @brief Basic memory test scenario using TLM components
 * 
 * This test scenario exercises the following functionality:
 * 1. TLB load operations
 * 2. Read/write transactions with byte masks
 * 3. Error handling for translation misses
 * 4. Sequential read-after-write verification
 */
class MemoryTestScenario : public sc_module
{
public:
    sc_in<bool> clk;
    sc_in<bool> rst_n;

    SC_HAS_PROCESS(MemoryTestScenario);
    
    MemoryTestScenario(sc_module_name name, 
                       MemoryInitiator *initiator,
                       MemoryScoreboard *scoreboard);
    virtual ~MemoryTestScenario();

    // Run the test scenario
    void run_tests();

    // Get test results
    bool get_test_passed() const { return test_passed; }
    unsigned int get_test_count() const { return test_count; }
    unsigned int get_test_passed_count() const { return tests_passed; }

private:
    MemoryInitiator *init;
    MemoryScoreboard *sb;
    bool test_passed;
    unsigned int test_count;
    unsigned int tests_passed;

    // Individual test methods
    void test_tlb_load();
    void test_basic_write();
    void test_basic_read();
    void test_masked_write();
    void test_sequential_rw();
    void test_error_handling();

    // Helper methods
    void wait_cycles(unsigned int n);
    void log_test(const std::string &name, bool passed);
};

#endif /* MEMORY_TEST_SCENARIO_H */
