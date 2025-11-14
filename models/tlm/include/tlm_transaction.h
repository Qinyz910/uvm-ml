#ifndef TLM_TRANSACTION_H
#define TLM_TRANSACTION_H

#include "tlm.h"
#include <cstdint>
#include <cstring>

/**
 * @brief TLM extension for memory transaction attributes
 * 
 * This extension captures memory-specific attributes that extend the
 * generic TLM payload to match RTL interface semantics.
 */
class MemoryTransaction : public tlm::tlm_extension<MemoryTransaction>
{
public:
    // Operation types matching RTL memory_pkg.sv
    enum OpType {
        OP_READ = 0x0,      // MEM_READ
        OP_WRITE = 0x1,     // MEM_WRITE
        OP_TLB_LOAD = 0x3   // MEM_TLB_LD
    };

    // Status codes matching RTL memory_pkg.sv
    enum StatusCode {
        STATUS_OK = 0x0,          // MEM_OK
        STATUS_ERR_ADDR = 0x1,    // MEM_ERR_ADDR (translation error)
        STATUS_ERR_ACCESS = 0x2,  // MEM_ERR_ACCESS (access violation)
        STATUS_ERR_WRITE = 0x3,   // MEM_ERR_WRITE
        STATUS_PENDING = 0xF      // MEM_PENDING
    };

    // Constructor
    MemoryTransaction() 
        : op_type(OP_READ),
          status(STATUS_PENDING),
          byte_mask(0xFF),
          virt_addr(0),
          phys_addr(0),
          data(0),
          tlb_virt_base(0),
          tlb_phys_base(0),
          timestamp(0),
          response_ready(false)
    {
    }

    // Copy constructor
    MemoryTransaction(const MemoryTransaction &rhs)
        : tlm::tlm_extension<MemoryTransaction>(rhs)
    {
        copy_from(rhs);
    }

    // Assignment operator
    MemoryTransaction &operator=(const MemoryTransaction &rhs)
    {
        copy_from(rhs);
        return *this;
    }

    // Clone method for TLM
    virtual tlm_extension_base *clone() const
    {
        return new MemoryTransaction(*this);
    }

    // Deep copy
    virtual void copy_from(const tlm_extension_base &ext)
    {
        const MemoryTransaction *from = dynamic_cast<const MemoryTransaction *>(&ext);
        if (from != nullptr) {
            op_type = from->op_type;
            status = from->status;
            byte_mask = from->byte_mask;
            virt_addr = from->virt_addr;
            phys_addr = from->phys_addr;
            data = from->data;
            tlb_virt_base = from->tlb_virt_base;
            tlb_phys_base = from->tlb_phys_base;
            timestamp = from->timestamp;
            response_ready = from->response_ready;
        }
    }

    // Transaction attributes
    OpType op_type;          // Operation type (read/write/tlb_load)
    StatusCode status;       // Response status
    uint32_t byte_mask;      // Byte mask for read/write (bits 0-7 for 64-bit data)
    uint64_t virt_addr;      // Virtual address for read/write
    uint64_t phys_addr;      // Translated physical address
    uint64_t data;           // Data (for write or read response)
    uint64_t tlb_virt_base;  // Virtual base for TLB load
    uint64_t tlb_phys_base;  // Physical base for TLB load
    uint64_t timestamp;      // Transaction timestamp
    bool response_ready;     // Response data valid
};

#endif /* TLM_TRANSACTION_H */
