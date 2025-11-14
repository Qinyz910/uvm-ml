// DPI Interface for Memory Module
// Provides C-callable interface to SystemVerilog memory module

#ifndef MEMORY_DPI_H
#define MEMORY_DPI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Status codes matching RTL
typedef enum {
    MEM_DPI_OK        = 0x0,
    MEM_DPI_ERR_ADDR  = 0x1,
    MEM_DPI_ERR_ACCESS = 0x2,
    MEM_DPI_ERR_WRITE = 0x3,
    MEM_DPI_PENDING   = 0xF
} mem_dpi_status_e;

// Transaction context for tracking pending operations
typedef struct {
    uint64_t virt_addr;
    uint64_t data;
    uint8_t  byte_mask;
    uint32_t timestamp;
} mem_dpi_context_t;

// DPI initialization and control
extern int memory_dpi_init(const char* rtl_module_path);
extern void memory_dpi_reset(void);
extern void memory_dpi_finalize(void);

// Read operations
extern mem_dpi_status_e memory_dpi_read(uint64_t virt_addr, uint8_t byte_mask, 
                                       uint64_t* data, uint32_t* timestamp);
extern int memory_dpi_read_async(uint64_t virt_addr, uint8_t byte_mask, 
                                mem_dpi_context_t* ctx);

// Write operations  
extern mem_dpi_status_e memory_dpi_write(uint64_t virt_addr, uint8_t byte_mask,
                                        uint64_t data, uint32_t* timestamp);
extern int memory_dpi_write_async(uint64_t virt_addr, uint8_t byte_mask,
                                 uint64_t data, mem_dpi_context_t* ctx);

// TLB operations
extern mem_dpi_status_e memory_dpi_tlb_load(uint64_t virt_base, uint64_t phys_base,
                                           uint32_t* timestamp);
extern int memory_dpi_tlb_load_async(uint64_t virt_base, uint64_t phys_base,
                                    mem_dpi_context_t* ctx);

// Status and query operations
extern int memory_dpi_get_response(mem_dpi_context_t* ctx, mem_dpi_status_e* status,
                                  uint64_t* data, uint32_t* timestamp);
extern uint32_t memory_dpi_get_tlb_entries(void);
extern int memory_dpi_is_ready(void);

// Debug and monitoring
extern void memory_dpi_enable_trace(int enable);
extern void memory_dpi_dump_state(void);

#ifdef __cplusplus
}
#endif

#endif // MEMORY_DPI_H