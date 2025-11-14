#include "memory_scoreboard.h"
#include <iostream>
#include <iomanip>
#include <sstream>

MemoryScoreboard::MemoryScoreboard(sc_module_name name)
    : sc_module(name), ref_model(nullptr), match_count(0), mismatch_count(0)
{
    // Create the reference model with default configuration
    memory_model_config_t cfg = memory_model_config_default();
    if (memory_model_create(&cfg, &ref_model) != MEMORY_MODEL_ERROR_OK) {
        SC_REPORT_ERROR("MemoryScoreboard", "Failed to create reference model");
        ref_model = nullptr;
    }
}

MemoryScoreboard::~MemoryScoreboard()
{
    report_mismatches();
    
    if (ref_model != nullptr) {
        memory_model_destroy(ref_model);
        ref_model = nullptr;
    }
}

void MemoryScoreboard::submit_request(const MemoryTransaction &req)
{
    if (!ref_model) {
        return;
    }
    
    // Store the request in pending queue
    PendingTransaction pending;
    pending.req = req;
    pending.expected_resp = new MemoryTransaction();
    pending.response_received = false;
    pending.request_time = sc_time_stamp();
    
    // Pre-compute expected response using reference model
    MemoryTransaction *expected = pending.expected_resp;
    memory_model_status_t status;
    
    switch (req.op_type) {
        case MemoryTransaction::OP_READ: {
            uint64_t data = 0;
            status = memory_model_read(ref_model, req.virt_addr, req.byte_mask, &data);
            expected->data = data;
            expected->status = static_cast<MemoryTransaction::StatusCode>(status);
            expected->virt_addr = req.virt_addr;
            expected->byte_mask = req.byte_mask;
            break;
        }
        
        case MemoryTransaction::OP_WRITE: {
            status = memory_model_write(ref_model, req.virt_addr, 
                                       req.byte_mask, req.data);
            expected->status = static_cast<MemoryTransaction::StatusCode>(status);
            expected->virt_addr = req.virt_addr;
            expected->byte_mask = req.byte_mask;
            expected->data = req.data;
            break;
        }
        
        case MemoryTransaction::OP_TLB_LOAD: {
            memory_model_error_t err = memory_model_load_tlb(ref_model,
                                                            req.tlb_virt_base,
                                                            req.tlb_phys_base);
            expected->status = (err == MEMORY_MODEL_ERROR_OK) ?
                             MemoryTransaction::STATUS_OK : MemoryTransaction::STATUS_ERR_ACCESS;
            expected->tlb_virt_base = req.tlb_virt_base;
            expected->tlb_phys_base = req.tlb_phys_base;
            break;
        }
        
        default:
            expected->status = MemoryTransaction::STATUS_ERR_ACCESS;
            break;
    }
    
    // Use the request timestamp as a key
    uint64_t key = req.timestamp;
    pending_queue[key] = pending;
}

void MemoryScoreboard::submit_response(const MemoryTransaction &resp)
{
    if (pending_queue.empty()) {
        SC_REPORT_WARNING("MemoryScoreboard", "Received response with no pending request");
        mismatch_count++;
        return;
    }
    
    // Find the corresponding request (simple FIFO assumption)
    auto it = pending_queue.begin();
    if (it != pending_queue.end()) {
        compare_responses(resp, *it->second.expected_resp);
        delete it->second.expected_resp;
        pending_queue.erase(it);
    }
}

void MemoryScoreboard::reset()
{
    if (ref_model != nullptr) {
        memory_model_reset(ref_model);
    }
    
    // Clean up pending queue
    for (auto &entry : pending_queue) {
        delete entry.second.expected_resp;
    }
    pending_queue.clear();
    
    match_count = 0;
    mismatch_count = 0;
}

void MemoryScoreboard::compare_responses(const MemoryTransaction &actual,
                                         const MemoryTransaction &expected)
{
    bool mismatch = false;
    std::stringstream ss;
    
    if (actual.op_type != expected.op_type) {
        ss << "Operation type mismatch: actual=" << std::hex << (int)actual.op_type
           << " expected=" << (int)expected.op_type << std::dec << "\n";
        mismatch = true;
    }
    
    if (actual.status != expected.status) {
        ss << "Status mismatch: actual=" << std::hex << (int)actual.status
           << " expected=" << (int)expected.status << std::dec << "\n";
        mismatch = true;
    }
    
    // For read/write, verify data and masks
    if (actual.op_type == MemoryTransaction::OP_READ ||
        actual.op_type == MemoryTransaction::OP_WRITE) {
        if (actual.data != expected.data) {
            ss << "Data mismatch: actual=0x" << std::hex << actual.data
               << " expected=0x" << expected.data << std::dec << "\n";
            mismatch = true;
        }
        
        if (actual.byte_mask != expected.byte_mask) {
            ss << "Byte mask mismatch: actual=0x" << std::hex << actual.byte_mask
               << " expected=0x" << expected.byte_mask << std::dec << "\n";
            mismatch = true;
        }
        
        if (actual.virt_addr != expected.virt_addr) {
            ss << "Virtual address mismatch: actual=0x" << std::hex << actual.virt_addr
               << " expected=0x" << expected.virt_addr << std::dec << "\n";
            mismatch = true;
        }
    }
    
    // For TLB load, verify base addresses
    if (actual.op_type == MemoryTransaction::OP_TLB_LOAD) {
        if (actual.tlb_virt_base != expected.tlb_virt_base) {
            ss << "TLB virt base mismatch: actual=0x" << std::hex << actual.tlb_virt_base
               << " expected=0x" << expected.tlb_virt_base << std::dec << "\n";
            mismatch = true;
        }
        
        if (actual.tlb_phys_base != expected.tlb_phys_base) {
            ss << "TLB phys base mismatch: actual=0x" << std::hex << actual.tlb_phys_base
               << " expected=0x" << expected.tlb_phys_base << std::dec << "\n";
            mismatch = true;
        }
    }
    
    if (mismatch) {
        mismatch_count++;
        SC_REPORT_WARNING("MemoryScoreboard", ss.str().c_str());
    } else {
        match_count++;
    }
}

bool MemoryScoreboard::verify_tlb_state()
{
    if (!ref_model) {
        return false;
    }
    
    // Verify TLB state against reference model
    unsigned int active = memory_model_active_entries(ref_model);
    unsigned int capacity = memory_model_tlb_capacity(ref_model);
    
    if (active > capacity) {
        SC_REPORT_ERROR("MemoryScoreboard", "Active TLB entries exceed capacity");
        return false;
    }
    
    return true;
}

void MemoryScoreboard::report_mismatches()
{
    if (mismatch_count == 0) {
        return;
    }
    
    std::stringstream ss;
    ss << "MemoryScoreboard Report:\n"
       << "  Total matches: " << match_count << "\n"
       << "  Total mismatches: " << mismatch_count << "\n"
       << "  Pending transactions: " << pending_queue.size() << "\n";
    
    SC_REPORT_INFO("MemoryScoreboard", ss.str().c_str());
}
