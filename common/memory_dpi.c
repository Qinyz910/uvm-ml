// DPI Implementation for Memory Module
// Bridge between C/SystemC and SystemVerilog RTL

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "memory_dpi.h"

// DPI import declarations - these will be bound to SystemVerilog
extern int sv_memory_dpi_init(const char* rtl_module_path);
extern void sv_memory_dpi_reset(void);
extern void sv_memory_dpi_finalize(void);

extern int sv_memory_dpi_read(uint64_t virt_addr, uint8_t byte_mask, 
                             uint64_t* data, uint32_t* timestamp);
extern int sv_memory_dpi_write(uint64_t virt_addr, uint8_t byte_mask,
                              uint64_t data, uint32_t* timestamp);
extern int sv_memory_dpi_tlb_load(uint64_t virt_base, uint64_t phys_base,
                                 uint32_t* timestamp);

extern int sv_memory_dpi_get_response(int ctx_id, int* status,
                                     uint64_t* data, uint32_t* timestamp);
extern uint32_t sv_memory_dpi_get_tlb_entries(void);
extern int sv_memory_dpi_is_ready(void);

extern void sv_memory_dpi_enable_trace(int enable);
extern void sv_memory_dpi_dump_state(void);

// Internal state
static int dpi_initialized = 0;
static int trace_enabled = 0;
static uint32_t next_context_id = 1;

// Helper function to check initialization
static int check_initialized(void) {
    if (!dpi_initialized) {
        fprintf(stderr, "Error: Memory DPI not initialized. Call memory_dpi_init() first.\n");
        return 0;
    }
    return 1;
}

// DPI initialization and control
int memory_dpi_init(const char* rtl_module_path) {
    if (dpi_initialized) {
        fprintf(stderr, "Warning: Memory DPI already initialized.\n");
        return 1;
    }
    
    printf("Initializing Memory DPI with RTL module: %s\n", rtl_module_path ? rtl_module_path : "default");
    
    int result = sv_memory_dpi_init(rtl_module_path);
    if (result) {
        dpi_initialized = 1;
        printf("Memory DPI initialized successfully.\n");
    } else {
        fprintf(stderr, "Error: Failed to initialize Memory DPI.\n");
    }
    
    return result;
}

void memory_dpi_reset(void) {
    if (!check_initialized()) return;
    
    sv_memory_dpi_reset();
    next_context_id = 1;
    printf("Memory DPI reset completed.\n");
}

void memory_dpi_finalize(void) {
    if (dpi_initialized) {
        sv_memory_dpi_finalize();
        dpi_initialized = 0;
        printf("Memory DPI finalized.\n");
    }
}

// Read operations
mem_dpi_status_e memory_dpi_read(uint64_t virt_addr, uint8_t byte_mask, 
                                uint64_t* data, uint32_t* timestamp) {
    if (!check_initialized()) return MEM_DPI_ERR_ACCESS;
    if (!data || !timestamp) {
        fprintf(stderr, "Error: NULL data or timestamp pointer in memory_dpi_read\n");
        return MEM_DPI_ERR_ACCESS;
    }
    
    if (trace_enabled) {
        printf("DPI READ: addr=0x%lx mask=0x%02x\n", virt_addr, byte_mask);
    }
    
    int sv_status = sv_memory_dpi_read(virt_addr, byte_mask, data, timestamp);
    return (mem_dpi_status_e)sv_status;
}

int memory_dpi_read_async(uint64_t virt_addr, uint8_t byte_mask, 
                         mem_dpi_context_t* ctx) {
    if (!check_initialized()) return -1;
    if (!ctx) return -1;
    
    ctx->virt_addr = virt_addr;
    ctx->byte_mask = byte_mask;
    ctx->timestamp = next_context_id++;
    
    // For now, just call synchronous version
    // In a real implementation, this would queue the request
    uint64_t data;
    uint32_t timestamp;
    mem_dpi_status_e status = memory_dpi_read(virt_addr, byte_mask, &data, &timestamp);
    
    return (status == MEM_DPI_OK) ? 0 : -1;
}

// Write operations
mem_dpi_status_e memory_dpi_write(uint64_t virt_addr, uint8_t byte_mask,
                                 uint64_t data, uint32_t* timestamp) {
    if (!check_initialized()) return MEM_DPI_ERR_ACCESS;
    if (!timestamp) {
        fprintf(stderr, "Error: NULL timestamp pointer in memory_dpi_write\n");
        return MEM_DPI_ERR_ACCESS;
    }
    
    if (trace_enabled) {
        printf("DPI WRITE: addr=0x%lx mask=0x%02x data=0x%lx\n", 
               virt_addr, byte_mask, data);
    }
    
    int sv_status = sv_memory_dpi_write(virt_addr, byte_mask, data, timestamp);
    return (mem_dpi_status_e)sv_status;
}

int memory_dpi_write_async(uint64_t virt_addr, uint8_t byte_mask,
                          uint64_t data, mem_dpi_context_t* ctx) {
    if (!check_initialized()) return -1;
    if (!ctx) return -1;
    
    ctx->virt_addr = virt_addr;
    ctx->byte_mask = byte_mask;
    ctx->data = data;
    ctx->timestamp = next_context_id++;
    
    // For now, just call synchronous version
    uint32_t timestamp;
    mem_dpi_status_e status = memory_dpi_write(virt_addr, byte_mask, data, &timestamp);
    
    return (status == MEM_DPI_OK) ? 0 : -1;
}

// TLB operations
mem_dpi_status_e memory_dpi_tlb_load(uint64_t virt_base, uint64_t phys_base,
                                     uint32_t* timestamp) {
    if (!check_initialized()) return MEM_DPI_ERR_ACCESS;
    if (!timestamp) {
        fprintf(stderr, "Error: NULL timestamp pointer in memory_dpi_tlb_load\n");
        return MEM_DPI_ERR_ACCESS;
    }
    
    if (trace_enabled) {
        printf("DPI TLB_LOAD: virt=0x%lx phys=0x%lx\n", virt_base, phys_base);
    }
    
    int sv_status = sv_memory_dpi_tlb_load(virt_base, phys_base, timestamp);
    return (mem_dpi_status_e)sv_status;
}

int memory_dpi_tlb_load_async(uint64_t virt_base, uint64_t phys_base,
                             mem_dpi_context_t* ctx) {
    if (!check_initialized()) return -1;
    if (!ctx) return -1;
    
    ctx->virt_addr = virt_base;
    ctx->data = phys_base;
    ctx->timestamp = next_context_id++;
    
    // For now, just call synchronous version
    uint32_t timestamp;
    mem_dpi_status_e status = memory_dpi_tlb_load(virt_base, phys_base, &timestamp);
    
    return (status == MEM_DPI_OK) ? 0 : -1;
}

// Status and query operations
int memory_dpi_get_response(mem_dpi_context_t* ctx, mem_dpi_status_e* status,
                           uint64_t* data, uint32_t* timestamp) {
    if (!check_initialized()) return -1;
    if (!ctx || !status) return -1;
    
    int sv_status;
    int result = sv_memory_dpi_get_response(ctx->timestamp, &sv_status, data, timestamp);
    *status = (mem_dpi_status_e)sv_status;
    
    return result;
}

uint32_t memory_dpi_get_tlb_entries(void) {
    if (!check_initialized()) return 0;
    return sv_memory_dpi_get_tlb_entries();
}

int memory_dpi_is_ready(void) {
    if (!check_initialized()) return 0;
    return sv_memory_dpi_is_ready();
}

// Debug and monitoring
void memory_dpi_enable_trace(int enable) {
    trace_enabled = enable;
    sv_memory_dpi_enable_trace(enable);
    printf("Memory DPI trace %s.\n", enable ? "enabled" : "disabled");
}

void memory_dpi_dump_state(void) {
    if (!check_initialized()) return;
    sv_memory_dpi_dump_state();
}