#include "memory_transactor.h"
#include <iostream>
#include <sstream>

// ============================================================================
// MemoryInitiator Implementation
// ============================================================================

MemoryInitiator::MemoryInitiator(sc_module_name name)
    : sc_module(name), socket("socket")
{
    SC_THREAD(main_process);
}

MemoryInitiator::~MemoryInitiator()
{
    // Clean up pending transactions
    while (!pending_transactions.empty()) {
        delete pending_transactions.front();
        pending_transactions.pop();
    }
}

void MemoryInitiator::send_read(uint64_t virt_addr, uint32_t byte_mask)
{
    transaction_type *trans = new transaction_type();
    MemoryTransaction *mem_ext = new MemoryTransaction();
    
    mem_ext->op_type = MemoryTransaction::OP_READ;
    mem_ext->virt_addr = virt_addr;
    mem_ext->byte_mask = byte_mask;
    mem_ext->timestamp = sc_time_stamp().value();
    
    trans->set_address(virt_addr);
    trans->set_read();
    trans->set_data_length(8);
    trans->set_data_ptr(reinterpret_cast<unsigned char *>(&mem_ext->data));
    trans->set_byte_enable_ptr(reinterpret_cast<unsigned char *>(&mem_ext->byte_mask));
    trans->set_extension(mem_ext);
    
    pending_transactions.push(trans);
    transaction_available.notify();
}

void MemoryInitiator::send_write(uint64_t virt_addr, uint32_t byte_mask, uint64_t data)
{
    transaction_type *trans = new transaction_type();
    MemoryTransaction *mem_ext = new MemoryTransaction();
    
    mem_ext->op_type = MemoryTransaction::OP_WRITE;
    mem_ext->virt_addr = virt_addr;
    mem_ext->byte_mask = byte_mask;
    mem_ext->data = data;
    mem_ext->timestamp = sc_time_stamp().value();
    
    trans->set_address(virt_addr);
    trans->set_write();
    trans->set_data_length(8);
    trans->set_data_ptr(reinterpret_cast<unsigned char *>(&mem_ext->data));
    trans->set_byte_enable_ptr(reinterpret_cast<unsigned char *>(&mem_ext->byte_mask));
    trans->set_extension(mem_ext);
    
    pending_transactions.push(trans);
    transaction_available.notify();
}

void MemoryInitiator::send_tlb_load(uint64_t virt_base, uint64_t phys_base)
{
    transaction_type *trans = new transaction_type();
    MemoryTransaction *mem_ext = new MemoryTransaction();
    
    mem_ext->op_type = MemoryTransaction::OP_TLB_LOAD;
    mem_ext->tlb_virt_base = virt_base;
    mem_ext->tlb_phys_base = phys_base;
    mem_ext->timestamp = sc_time_stamp().value();
    
    trans->set_address(0);
    trans->set_read();
    trans->set_extension(mem_ext);
    
    pending_transactions.push(trans);
    transaction_available.notify();
}

// No explicit interface methods needed - simple_initiator_socket handles this

void MemoryInitiator::main_process()
{
    while (true) {
        wait(transaction_available | sc_event(sc_gen_unique_name("timeout")));
        
        while (!pending_transactions.empty()) {
            transaction_type *trans = pending_transactions.front();
            pending_transactions.pop();
            
            tlm::tlm_generic_payload *payload = trans;
            tlm::tlm_phase phase = tlm::BEGIN_REQ;
            sc_time delay = sc_time(0, SC_NS);
            
            socket->nb_transport_fw(*payload, phase, delay);
            
            delete trans;
        }
    }
}

// ============================================================================
// MemoryTarget Implementation
// ============================================================================

MemoryTarget::MemoryTarget(sc_module_name name, memory_model_t *model)
    : sc_module(name), socket("socket"), mem_model(model),
      transactions_processed(0), error_count(0)
{
    socket.register_b_transport(this, &MemoryTarget::process_transaction);
}

MemoryTarget::~MemoryTarget()
{
}

void MemoryTarget::process_transaction(transaction_type &trans, sc_time &delay)
{
    MemoryTransaction *mem_ext = nullptr;
    trans.get_extension(mem_ext);
    
    if (!mem_ext || !mem_model) {
        trans.set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
        return;
    }
    
    memory_model_status_t status;
    
    switch (mem_ext->op_type) {
        case MemoryTransaction::OP_READ: {
            uint64_t data = 0;
            status = memory_model_read(mem_model, mem_ext->virt_addr, 
                                      mem_ext->byte_mask, &data);
            mem_ext->data = data;
            mem_ext->status = static_cast<MemoryTransaction::StatusCode>(status);
            mem_ext->response_ready = true;
            transactions_processed++;
            if (status != MEMORY_MODEL_STATUS_OK) {
                error_count++;
            }
            break;
        }
        
        case MemoryTransaction::OP_WRITE: {
            status = memory_model_write(mem_model, mem_ext->virt_addr,
                                       mem_ext->byte_mask, mem_ext->data);
            mem_ext->status = static_cast<MemoryTransaction::StatusCode>(status);
            mem_ext->response_ready = true;
            transactions_processed++;
            if (status != MEMORY_MODEL_STATUS_OK) {
                error_count++;
            }
            break;
        }
        
        case MemoryTransaction::OP_TLB_LOAD: {
            memory_model_error_t err = memory_model_load_tlb(mem_model,
                                                            mem_ext->tlb_virt_base,
                                                            mem_ext->tlb_phys_base);
            mem_ext->status = (err == MEMORY_MODEL_ERROR_OK) ? 
                             MemoryTransaction::STATUS_OK : MemoryTransaction::STATUS_ERR_ACCESS;
            mem_ext->response_ready = true;
            transactions_processed++;
            if (err != MEMORY_MODEL_ERROR_OK) {
                error_count++;
            }
            break;
        }
        
        default:
            error_count++;
            trans.set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
            return;
    }
    
    trans.set_response_status(tlm::TLM_OK_RESPONSE);
}

// ============================================================================
// MemoryMonitor Implementation
// ============================================================================

MemoryMonitor::MemoryMonitor(sc_module_name name)
    : sc_module(name), transaction_count(0), read_count(0), write_count(0), tlb_load_count(0)
{
}

void MemoryMonitor::observe_transaction(const MemoryTransaction &trans)
{
    transaction_count++;
    
    switch (trans.op_type) {
        case MemoryTransaction::OP_READ:
            read_count++;
            break;
        case MemoryTransaction::OP_WRITE:
            write_count++;
            break;
        case MemoryTransaction::OP_TLB_LOAD:
            tlb_load_count++;
            break;
        default:
            break;
    }
}
