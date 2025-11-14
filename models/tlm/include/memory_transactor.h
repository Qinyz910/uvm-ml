#ifndef MEMORY_TRANSACTOR_H
#define MEMORY_TRANSACTOR_H

#include "systemc.h"
#include "tlm.h"
#include "tlm_utils/simple_initiator_socket.h"
#include "tlm_utils/simple_target_socket.h"
#include "tlm_transaction.h"
#include "memory_model.h"
#include <queue>

/**
 * @brief TLM Initiator that drives memory transactions to the target
 * 
 * The MemoryInitiator sends read/write transactions via its TLM socket.
 * It can be connected to a target model (like the RTL via DPI or the
 * reference model directly).
 */
class MemoryInitiator : public sc_module
{
public:
    typedef tlm::tlm_generic_payload transaction_type;
    typedef tlm::tlm_phase phase_type;
    typedef tlm::tlm_sync_enum sync_enum_type;

    // TLM socket
    tlm_utils::simple_initiator_socket<MemoryInitiator> socket;

    SC_HAS_PROCESS(MemoryInitiator);
    
    MemoryInitiator(sc_module_name name);
    virtual ~MemoryInitiator();

    // Push a transaction to the queue for sending
    void send_read(uint64_t virt_addr, uint32_t byte_mask);
    void send_write(uint64_t virt_addr, uint32_t byte_mask, uint64_t data);
    void send_tlb_load(uint64_t virt_base, uint64_t phys_base);

private:
    void main_process();
    std::queue<transaction_type *> pending_transactions;
    sc_event transaction_available;
};

/**
 * @brief TLM Target that receives and processes memory transactions
 * 
 * The MemoryTarget receives transactions from the initiator via TLM.
 * This is a placeholder for eventual connection to RTL via DPI or
 * direct connection to the reference model.
 */
class MemoryTarget : public sc_module
{
public:
    typedef tlm::tlm_generic_payload transaction_type;
    typedef tlm::tlm_phase phase_type;
    typedef tlm::tlm_sync_enum sync_enum_type;

    // TLM socket
    tlm_utils::simple_target_socket<MemoryTarget> socket;

    SC_HAS_PROCESS(MemoryTarget);
    
    MemoryTarget(sc_module_name name, memory_model_t *model = nullptr);
    virtual ~MemoryTarget();

    // Set the reference model for this target
    void set_memory_model(memory_model_t *model) { mem_model = model; }

    // Get transaction statistics
    unsigned int get_transactions_processed() const { return transactions_processed; }
    unsigned int get_errors() const { return error_count; }

private:
    memory_model_t *mem_model;
    unsigned int transactions_processed;
    unsigned int error_count;

    void process_transaction(transaction_type &trans, sc_time &delay);
};

/**
 * @brief Monitor that observes TLM transactions
 * 
 * Captures both requests and responses for debugging, logging, and
 * coverage collection.
 */
class MemoryMonitor : public sc_module
{
public:
    sc_in<bool> clk;
    sc_in<bool> rst_n;

    SC_HAS_PROCESS(MemoryMonitor);
    
    MemoryMonitor(sc_module_name name);
    virtual ~MemoryMonitor() {};

    // Register a transaction for monitoring
    void observe_transaction(const MemoryTransaction &trans);

    // Get statistics
    unsigned int get_transaction_count() const { return transaction_count; }
    unsigned int get_read_count() const { return read_count; }
    unsigned int get_write_count() const { return write_count; }
    unsigned int get_tlb_load_count() const { return tlb_load_count; }

private:
    unsigned int transaction_count;
    unsigned int read_count;
    unsigned int write_count;
    unsigned int tlb_load_count;
};

#endif /* MEMORY_TRANSACTOR_H */
