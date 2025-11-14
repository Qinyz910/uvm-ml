#include "systemc.h"
#include "tlm.h"
#include "memory_transactor.h"
#include "memory_scoreboard.h"
#include "memory_test_scenario.h"
#include "memory_model.h"

/**
 * @brief Top-level TLM testbench
 * 
 * This testbench instantiates the TLM components and connects them:
 * - MemoryInitiator: TLM master that issues transactions
 * - MemoryTarget: TLM slave that processes transactions using the reference model
 * - MemoryScoreboard: Verification component that checks responses
 * - MemoryTestScenario: Test driver that exercises the system
 */
class MemoryTLMTestBench : public sc_module
{
public:
    SC_HAS_PROCESS(MemoryTLMTestBench);
    
    MemoryTLMTestBench(sc_module_name name)
        : sc_module(name)
    {
        // Create components
        initiator = new MemoryInitiator("initiator");
        target = new MemoryTarget("target");
        scoreboard = new MemoryScoreboard("scoreboard");
        test_scenario = new MemoryTestScenario("test_scenario", initiator, scoreboard);
        
        // Connect initiator to target via TLM
        initiator->socket.bind(target->socket);
        
        // Create reference model for the target
        memory_model_t *ref_model = nullptr;
        memory_model_config_t cfg = memory_model_config_default();
        if (memory_model_create(&cfg, &ref_model) == MEMORY_MODEL_ERROR_OK) {
            target->set_memory_model(ref_model);
        }
        
        SC_THREAD(monitor_process);
    }
    
    virtual ~MemoryTLMTestBench()
    {
        delete test_scenario;
        delete scoreboard;
        delete target;
        delete initiator;
    }
    
private:
    MemoryInitiator *initiator;
    MemoryTarget *target;
    MemoryScoreboard *scoreboard;
    MemoryTestScenario *test_scenario;
    
    void monitor_process()
    {
        while (true) {
            wait(1, SC_US);
            
            if (sc_time_stamp() > sc_time(1, SC_MS)) {
                break;
            }
        }
    }
};

/**
 * @brief Main simulation entry point
 */
int sc_main(int argc, char *argv[])
{
    std::cout << "=== Memory TLM Testbench ===" << std::endl;
    std::cout << "SystemC Version: " << SC_VERSION << std::endl;
    std::cout << std::endl;
    
    // Create the testbench
    MemoryTLMTestBench tb("tb");
    
    // Run simulation
    std::cout << "Starting simulation..." << std::endl;
    sc_start();
    
    std::cout << "\nSimulation completed at " << sc_time_stamp() << std::endl;
    
    return 0;
}
