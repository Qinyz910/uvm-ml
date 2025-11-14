#ifndef MEMORY_DPI_TRANSACTOR_H
#define MEMORY_DPI_TRANSACTOR_H

#include "systemc.h"
#include "tlm.h"
#include "tlm_utils/simple_initiator_socket.h"
#include "tlm_utils/simple_target_socket.h"
#include "memory_transactor.h"
#include "tlm_transaction.h"

#include "../../common/memory_dpi.h"

#include <iostream>
#include <string>

using namespace std;

// DPI Bridge Transactor - Connects TLM to RTL via DPI
class MemoryDPIBridge : public sc_module, public MemoryTarget {
public:
    // TLM socket
    tlm_utils::simple_target_socket<MemoryDPIBridge> socket;
    
    // Constructor
    SC_HAS_PROCESS(MemoryDPIBridge);
    MemoryDPIBridge(sc_module_name name, memory_model_t* ref_model = nullptr) 
        : sc_module(name), socket("socket"), MemoryTarget(name, ref_model) {
        
        socket.bind(*this);
        
        SC_THREAD(process_dpi_thread);
        sensitive << clk.pos();
        
        // Initialize DPI
        if (!memory_dpi_init("memory_dpi_bridge")) {
            SC_REPORT_FATAL("MemoryDPIBridge", "Failed to initialize Memory DPI");
        }
        
        cout << "MemoryDPIBridge initialized successfully" << endl;
    }
    
    // Destructor
    ~MemoryDPIBridge() {
        memory_dpi_finalize();
    }
    
    // SystemC clock for timing
    sc_in<bool> clk;
    
protected:
    // TLM transport interface
    virtual tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& trans,
                                              tlm::tlm_phase& phase,
                                              sc_time& delay) {
        
        if (phase != tlm::BEGIN_REQ) {
            return tlm::TLM_REJECTED;
        }
        
        MemoryTransaction* mem_trans = 
            static_cast<MemoryTransaction*>(trans.get_extension<MemoryTransaction>());
        
        if (!mem_trans) {
            SC_REPORT_ERROR("MemoryDPIBridge", "No MemoryTransaction extension found");
            return tlm::TLM_REJECTED;
        }
        
        // Process transaction via DPI
        process_dpi_transaction(*mem_trans);
        
        // Complete transaction
        phase = tlm::END_REQ;
        delay = sc_time(10, SC_NS); // RTL processing delay
        
        return tlm::TLM_UPDATED;
    }
    
    // DPI transaction processing thread
    void process_dpi_thread() {
        while (true) {
            wait();
            // DPI transactions are processed synchronously in nb_transport_fw
        }
    }
    
    // Process individual transaction via DPI
    void process_dpi_transaction(MemoryTransaction& trans) {
        mem_dpi_status_e status;
        uint32_t timestamp;
        uint64_t data = 0;
        
        trans.timestamp = sc_time_stamp().value();
        
        switch (trans.op_type) {
            case MemoryTransaction::OP_READ: {
                status = memory_dpi_read(trans.virt_addr, trans.byte_mask, 
                                        &data, &timestamp);
                trans.data = data;
                trans.status = convert_dpi_status(status);
                
                cout << sc_time_stamp() << " [DPI_BRIDGE] READ: "
                     << "addr=0x" << hex << trans.virt_addr 
                     << " data=0x" << trans.data
                     << " status=" << trans.status << dec << endl;
                break;
            }
            
            case MemoryTransaction::OP_WRITE: {
                status = memory_dpi_write(trans.virt_addr, trans.byte_mask,
                                         trans.data, &timestamp);
                trans.status = convert_dpi_status(status);
                
                cout << sc_time_stamp() << " [DPI_BRIDGE] WRITE: "
                     << "addr=0x" << hex << trans.virt_addr 
                     << " data=0x" << trans.data
                     << " status=" << trans.status << dec << endl;
                break;
            }
            
            case MemoryTransaction::OP_TLB_LOAD: {
                status = memory_dpi_tlb_load(trans.tlb_virt_base, trans.tlb_phys_base,
                                           &timestamp);
                trans.status = convert_dpi_status(status);
                
                cout << sc_time_stamp() << " [DPI_BRIDGE] TLB_LOAD: "
                     << "virt=0x" << hex << trans.tlb_virt_base
                     << " phys=0x" << trans.tlb_phys_base
                     << " status=" << trans.status << dec << endl;
                break;
            }
            
            default:
                SC_REPORT_ERROR("MemoryDPIBridge", "Unknown operation type");
                trans.status = MemoryTransaction::STATUS_ERR_ACCESS;
                break;
        }
        
        // Also update reference model if available
        if (ref_model) {
            process_transaction_with_ref_model(trans);
        }
    }
    
    // Convert DPI status to TLM status
    MemoryTransaction::status_e convert_dpi_status(mem_dpi_status_e dpi_status) {
        switch (dpi_status) {
            case MEM_DPI_OK:        return MemoryTransaction::STATUS_OK;
            case MEM_DPI_ERR_ADDR:  return MemoryTransaction::STATUS_ERR_ADDR;
            case MEM_DPI_ERR_ACCESS: return MemoryTransaction::STATUS_ERR_ACCESS;
            case MEM_DPI_ERR_WRITE: return MemoryTransaction::STATUS_ERR_WRITE;
            case MEM_DPI_PENDING:   return MemoryTransaction::STATUS_PENDING;
            default:                return MemoryTransaction::STATUS_ERR_ACCESS;
        }
    }
    
    // Process transaction with reference model for comparison
    void process_transaction_with_ref_model(MemoryTransaction& trans) {
        if (!ref_model) return;
        
        memory_transaction_t ref_trans;
        memory_result_t ref_result;
        
        // Convert to reference model format
        switch (trans.op_type) {
            case MemoryTransaction::OP_READ:
                ref_trans.type = MEMORY_READ;
                ref_trans.virt_addr = trans.virt_addr;
                ref_trans.byte_mask = trans.byte_mask;
                break;
                
            case MemoryTransaction::OP_WRITE:
                ref_trans.type = MEMORY_WRITE;
                ref_trans.virt_addr = trans.virt_addr;
                ref_trans.byte_mask = trans.byte_mask;
                ref_trans.data = trans.data;
                break;
                
            case MemoryTransaction::OP_TLB_LOAD:
                ref_trans.type = MEMORY_TLB_LOAD;
                ref_trans.tlb_virt_base = trans.tlb_virt_base;
                ref_trans.tlb_phys_base = trans.tlb_phys_base;
                break;
        }
        
        // Execute in reference model
        memory_model_execute(ref_model, &ref_trans, &ref_result);
        
        // Compare results (for debugging)
        if (ref_result.status == MEMORY_OK && trans.status == MemoryTransaction::STATUS_OK) {
            if (trans.op_type == MemoryTransaction::OP_READ) {
                if (ref_result.data != trans.data) {
                    cout << sc_time_stamp() << " [DPI_BRIDGE] WARNING: "
                         << "RTL vs Ref Model data mismatch: "
                         << "RTL=0x" << hex << trans.data
                         << " Ref=0x" << ref_result.data << dec << endl;
                }
            }
        }
    }
    
private:
    // Reference model instance for comparison
    memory_model_t* ref_model;
};

#endif // MEMORY_DPI_TRANSACTOR_H