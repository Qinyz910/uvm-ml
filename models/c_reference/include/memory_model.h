#ifndef MEMORY_MODEL_H
#define MEMORY_MODEL_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Configuration parameters for the C reference memory model.
 */
typedef struct {
    uint32_t virt_addr_width; /**< Width of the virtual address space in bits */
    uint32_t phys_addr_width; /**< Width of the physical address space in bits */
    uint32_t page_size;       /**< Size of a page in bytes (must be a power of two) */
    uint32_t data_width;      /**< Data width in bits (must be a multiple of 8, up to 64) */
    uint32_t mem_depth;       /**< Number of addressable entries in the backing store */
    uint32_t tlb_entries;     /**< Number of translation entries tracked in the TLB */
} memory_model_config_t;

/**
 * @brief Transaction status codes that mirror the RTL implementation.
 */
typedef enum {
    MEMORY_MODEL_STATUS_OK = 0,
    MEMORY_MODEL_STATUS_ERR_ADDR = 1,
    MEMORY_MODEL_STATUS_ERR_ACCESS = 2,
    MEMORY_MODEL_STATUS_ERR_WRITE = 3,
    MEMORY_MODEL_STATUS_PENDING = 0xF
} memory_model_status_t;

/**
 * @brief Function result codes for control/management APIs.
 */
typedef enum {
    MEMORY_MODEL_ERROR_OK = 0,
    MEMORY_MODEL_ERROR_BAD_ARGUMENT = -1,
    MEMORY_MODEL_ERROR_OUT_OF_MEMORY = -2,
    MEMORY_MODEL_ERROR_UNSUPPORTED = -3
} memory_model_error_t;

/**
 * @brief Opaque handle to an instantiated memory model.
 */
typedef struct memory_model memory_model_t;

/**
 * @brief Convenience helper that returns the default configuration used by the RTL.
 */
memory_model_config_t memory_model_config_default(void);

/**
 * @brief Construct a memory model instance using the provided configuration.
 *
 * @param config   Pointer to configuration parameters. If NULL, defaults are used.
 * @param model_out Pointer that receives the allocated model on success.
 *
 * @return MEMORY_MODEL_ERROR_OK on success or an error code otherwise.
 */
memory_model_error_t memory_model_create(const memory_model_config_t *config,
                                          memory_model_t **model_out);

/**
 * @brief Release all resources held by the model.
 */
void memory_model_destroy(memory_model_t *model);

/**
 * @brief Reset memory contents and translation state to power-on defaults.
 */
memory_model_error_t memory_model_reset(memory_model_t *model);

/**
 * @brief Load a virtual-to-physical mapping into the model's TLB.
 *
 * The implementation follows the RTL behaviour: entries are written using a
 * round-robin pointer that wraps after the configured capacity is reached.
 */
memory_model_error_t memory_model_load_tlb(memory_model_t *model,
                                           uint64_t virt_base,
                                           uint64_t phys_base);

/**
 * @brief Perform a pure translation without touching memory storage.
 */
memory_model_status_t memory_model_translate(const memory_model_t *model,
                                              uint64_t virt_addr,
                                              uint64_t *phys_addr_out);

/**
 * @brief Issue a masked read transaction using a virtual address.
 */
memory_model_status_t memory_model_read(const memory_model_t *model,
                                         uint64_t virt_addr,
                                         uint32_t byte_mask,
                                         uint64_t *data_out);

/**
 * @brief Issue a masked write transaction using a virtual address.
 */
memory_model_status_t memory_model_write(memory_model_t *model,
                                          uint64_t virt_addr,
                                          uint32_t byte_mask,
                                          uint64_t data);

/**
 * @brief Query the number of active (valid) TLB entries.
 */
uint32_t memory_model_active_entries(const memory_model_t *model);

/**
 * @brief Retrieve the round-robin write index used for the next TLB insertion.
 */
uint32_t memory_model_tlb_write_index(const memory_model_t *model);

/**
 * @brief Retrieve the configured TLB capacity.
 */
uint32_t memory_model_tlb_capacity(const memory_model_t *model);

/**
 * @brief Access the configuration associated with the instance.
 */
const memory_model_config_t *memory_model_get_config(const memory_model_t *model);

#ifdef __cplusplus
}
#endif

#endif /* MEMORY_MODEL_H */
