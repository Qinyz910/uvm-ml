#include "systemc.h"
#include "tlm_utils/tlm_quantumkeeper.h"
#include "memory_transactor.h"
#include "memory_scoreboard.h"
#include "memory_test_scenario.h"
#include "memory_dpi_transactor.h"

#include <iostream>
#include <iomanip>

using namespace std;

// Enhanced TLM Testbench with DPI Bridge Integration
class MemoryTLMDPITestBench : public sc_module {
public:
    // Constructor
    SC_HAS_PROCESS(MemoryTLMDPITestBench);
    MemoryTLMDPITestBench(sc_module_name name) : sc_module(name) {
        
        cout << "=== Memory TLM-DPI Testbench ===" << endl;
        cout << "SystemC Version: " << SC_VERSION << endl;
        cout << "Building testbench components..." << endl;
        
        // Initialize reference model first
        memory_config_t ref_config;
        ref_config.virt_addr_width = 32;
        ref_config.phys_addr_width = 28;
        ref_config.mem_depth = 16384;
        ref_config.page_size = 4096;
        ref_config.data_width = 64;
        ref_config.tlb_entries = 256;
        
        if (memory_model_create(&ref_config, &ref_model) != MEMORY_OK) {
            SC_REPORT_FATAL("MemoryTLMDPITestBench", "Failed to create reference model");
        }
        
        // Create components
        initiator = new MemoryInitiator("initiator");
        scoreboard = new MemoryScoreboard("scoreboard");
        dpi_bridge = new MemoryDPIBridge("dpi_bridge", ref_model);
        test_scenario = new MemoryTestScenario("test_scenario", initiator, scoreboard);
        
        // Clock for DPI bridge
        sc_clock clk("clk", sc_time(10, SC_NS)); // 100 MHz clock
        
        // Connect clock to DPI bridge
        dpi_bridge->clk(clk);
        
        // Bind initiator to DPI bridge (instead of regular target)
        initiator->socket.bind(dpi_bridge->socket);
        
        // Connect scoreboard to monitor transactions
        initiator->ap.bind(*scoreboard);
        
        // Main test process
        SC_THREAD(main_test_process);
        
        cout << "Testbench construction complete." << endl;
    }
    
    // Destructor
    ~MemoryTLMDPITestBench() {
        delete test_scenario;
        delete dpi_bridge;
        delete scoreboard;
        delete initiator;
        
        if (ref_model) {
            memory_model_destroy(ref_model);
        }
    }

protected:
    // Main test process
    void main_test_process() {
        cout << "\n=== Memory TLM-DPI Test Scenario Starting ===" << endl;
        cout << "@" << sc_time_stamp() << endl;
        
        // Enable DPI tracing for debugging
        memory_dpi_enable_trace(1);
        
        // Run the test scenarios
        test_scenario->run_tests();
        
        // Wait for all transactions to complete
        wait(sc_time(100, SC_NS));
        
        // Generate final report
        generate_final_report();
        
        cout << "\n=== Memory TLM-DPI Test Scenario Complete ===" << endl;
        sc_stop();
    }
    
    // Generate final test report
    void generate_final_report() {
        cout << "\n=== Final Test Report ===" << endl;
        
        // Scoreboard results
        unsigned int matches = scoreboard->get_matches();
        unsigned int mismatches = scoreboard->get_mismatches();
        unsigned int total_transactions = matches + mismatches;
        
        cout << "Total Transactions: " << total_transactions << endl;
        cout << "Matches: " << matches << endl;
        cout << "Mismatches: " << mismatches << endl;
        
        if (total_transactions > 0) {
            double match_rate = (double)matches / total_transactions * 100.0;
            cout << "Match Rate: " << fixed << setprecision(2) << match_rate << "%" << endl;
        }
        
        // TLB status from DPI
        uint32_t tlb_entries = memory_dpi_get_tlb_entries();
        cout << "Active TLB Entries: " << tlb_entries << endl;
        
        // Reference model statistics
        memory_stats_t ref_stats;
        if (memory_model_get_stats(ref_model, &ref_stats) == MEMORY_OK) {
            cout << "Reference Model Statistics:" << endl;
            cout << "  Reads: " << ref_stats.read_count << endl;
            cout << "  Writes: " << ref_stats.write_count << endl;
            cout << "  TLB Loads: " << ref_stats.tlb_load_count << endl;
            cout << "  TLB Hits: " << ref_stats.tlb_hits << endl;
            cout << "  TLB Misses: " << ref_stats.tlb_misses << endl;
        }
        
        // Overall result
        if (mismatches == 0 && total_transactions > 0) {
            cout << "\nOverall Result: PASS" << endl;
            cout << "All transactions matched between RTL and reference model!" << endl;
        } else if (total_transactions == 0) {
            cout << "\nOverall Result: INCONCLUSIVE" << endl;
            cout << "No transactions were executed." << endl;
        } else {
            cout << "\nOverall Result: FAIL" << endl;
            cout << mismatches << " out of " << total_transactions 
                 << " transactions had mismatches." << endl;
        }
        
        cout << "Simulation completed at " << sc_time_stamp() << endl;
    }

private:
    // Testbench components
    MemoryInitiator* initiator;
    MemoryScoreboard* scoreboard;
    MemoryDPIBridge* dpi_bridge;
    MemoryTestScenario* test_scenario;
    
    // Reference model
    memory_model_t* ref_model;
};

// Main function for standalone execution
int sc_main(int argc, char* argv[]) {
    try {
        // Create testbench
        MemoryTLMDPITestBench testbench("testbench");
        
        // Start simulation
        cout << "\nStarting simulation..." << endl;
        sc_start();
        
        cout << "Simulation finished successfully." << endl;
        return 0;
        
    } catch (const std::exception& e) {
        cerr << "Simulation failed with exception: " << e.what() << endl;
        return 1;
    } catch (...) {
        cerr << "Simulation failed with unknown exception" << endl;
        return 1;
    }
}