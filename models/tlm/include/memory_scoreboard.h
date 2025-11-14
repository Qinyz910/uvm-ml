#ifndef MEMORY_SCOREBOARD_H
#define MEMORY_SCOREBOARD_H

#include "systemc.h"
#include "tlm_transaction.h"
#include "memory_model.h"
#include <vector>
#include <map>
#include <cstdint>

/**
 * @brief Scoreboard for memory transaction verification
 * 
 * The scoreboard maintains shadow copies of the memory state using the
 * C reference model and compares DUT responses against expected values.
 * It logs mismatches and maintains coverage statistics.
 */
class MemoryScoreboard : public sc_module
{
public:
    sc_in<bool> clk;
    sc_in<bool> rst_n;

    SC_HAS_PROCESS(MemoryScoreboard);
    
    MemoryScoreboard(sc_module_name name);
    virtual ~MemoryScoreboard();

    // Submit transactions for verification
    void submit_request(const MemoryTransaction &req);
    void submit_response(const MemoryTransaction &resp);

    // Reset internal state
    void reset();

    // Get statistics
    unsigned int get_matches() const { return match_count; }
    unsigned int get_mismatches() const { return mismatch_count; }
    unsigned int get_pending_transactions() const { return pending_queue.size(); }

    // Dump mismatches to console
    void report_mismatches();

private:
    struct PendingTransaction {
        MemoryTransaction req;
        MemoryTransaction *expected_resp;
        bool response_received;
        sc_time request_time;
    };

    memory_model_t *ref_model;
    std::map<uint64_t, PendingTransaction> pending_queue;
    unsigned int match_count;
    unsigned int mismatch_count;

    void process_response();
    void compare_responses(const MemoryTransaction &actual, 
                          const MemoryTransaction &expected);
    bool verify_tlb_state();
};

#endif /* MEMORY_SCOREBOARD_H */
