#include "memory_model.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

struct tlb_entry {
    bool valid;
    uint64_t virt_base;
    uint64_t phys_base;
};

struct memory_model {
    memory_model_config_t cfg;
    struct tlb_entry *tlb;
    uint8_t *memory;

    uint32_t tlb_write_ptr;
    uint32_t active_entries;

    uint32_t bytes_per_word;
    uint32_t page_offset_bits;
    uint32_t mem_addr_bits;

    bool mem_depth_pow2;

    uint64_t virt_addr_mask;
    uint64_t phys_addr_mask;
    uint64_t page_offset_mask;
    uint64_t mem_addr_mask;
    uint64_t data_mask;
};

static bool is_power_of_two(uint32_t value)
{
    return value != 0U && (value & (value - 1U)) == 0U;
}

static uint32_t ceil_log2_u32(uint32_t value)
{
    if (value <= 1U) {
        return 0U;
    }

    uint32_t width = 0U;
    uint32_t tmp = value - 1U;
    while (tmp > 0U) {
        tmp >>= 1U;
        width++;
    }
    return width;
}

static uint64_t mask_from_width(uint32_t width)
{
    if (width == 0U) {
        return 0ULL;
    }
    if (width >= 64U) {
        return UINT64_MAX;
    }
    return (1ULL << width) - 1ULL;
}

static uint32_t byte_mask_for_word(uint32_t bytes_per_word)
{
    if (bytes_per_word == 0U) {
        return 0U;
    }
    if (bytes_per_word >= 32U) {
        return UINT32_MAX;
    }
    return (1U << bytes_per_word) - 1U;
}

memory_model_config_t memory_model_config_default(void)
{
    memory_model_config_t cfg;
    cfg.virt_addr_width = 32U;
    cfg.phys_addr_width = 28U;
    cfg.page_size = 4096U;
    cfg.data_width = 64U;
    cfg.mem_depth = 16384U;
    cfg.tlb_entries = 256U;
    return cfg;
}

memory_model_error_t memory_model_create(const memory_model_config_t *config,
                                          memory_model_t **model_out)
{
    if (model_out == NULL) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }

    *model_out = NULL;

    memory_model_config_t local_cfg = config != NULL ? *config : memory_model_config_default();

    if (local_cfg.data_width == 0U || (local_cfg.data_width % 8U) != 0U || local_cfg.data_width > 64U) {
        return MEMORY_MODEL_ERROR_UNSUPPORTED;
    }
    if (local_cfg.page_size == 0U || !is_power_of_two(local_cfg.page_size)) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }
    if (local_cfg.mem_depth == 0U || local_cfg.tlb_entries == 0U) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }
    if (local_cfg.virt_addr_width == 0U || local_cfg.virt_addr_width > 64U) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }
    if (local_cfg.phys_addr_width == 0U || local_cfg.phys_addr_width > 64U) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }

    uint32_t page_offset_bits = ceil_log2_u32(local_cfg.page_size);
    if (page_offset_bits > local_cfg.virt_addr_width || page_offset_bits > local_cfg.phys_addr_width) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }

    memory_model_t *model = calloc(1U, sizeof(*model));
    if (model == NULL) {
        return MEMORY_MODEL_ERROR_OUT_OF_MEMORY;
    }

    model->cfg = local_cfg;
    model->bytes_per_word = (uint32_t)(local_cfg.data_width / 8U);
    model->page_offset_bits = page_offset_bits;
    model->page_offset_mask = mask_from_width(page_offset_bits);
    model->virt_addr_mask = mask_from_width(local_cfg.virt_addr_width);
    model->phys_addr_mask = mask_from_width(local_cfg.phys_addr_width);
    model->data_mask = mask_from_width(local_cfg.data_width);

    model->mem_addr_bits = ceil_log2_u32(local_cfg.mem_depth);
    model->mem_depth_pow2 = is_power_of_two(local_cfg.mem_depth);
    if (model->mem_depth_pow2 && local_cfg.mem_depth > 0U) {
        model->mem_addr_mask = (uint64_t)local_cfg.mem_depth - 1ULL;
    } else if (model->mem_addr_bits >= 64U) {
        model->mem_addr_mask = UINT64_MAX;
    } else if (model->mem_addr_bits == 0U) {
        model->mem_addr_mask = 0ULL;
    } else {
        model->mem_addr_mask = (1ULL << model->mem_addr_bits) - 1ULL;
    }

    size_t total_bytes = (size_t)local_cfg.mem_depth * (size_t)model->bytes_per_word;
    if (local_cfg.mem_depth != 0U && model->bytes_per_word != 0U) {
        if (total_bytes / local_cfg.mem_depth != (size_t)model->bytes_per_word) {
            free(model);
            return MEMORY_MODEL_ERROR_UNSUPPORTED;
        }
    }

    model->memory = calloc(total_bytes, 1U);
    if (model->memory == NULL) {
        free(model);
        return MEMORY_MODEL_ERROR_OUT_OF_MEMORY;
    }

    model->tlb = calloc(local_cfg.tlb_entries, sizeof(struct tlb_entry));
    if (model->tlb == NULL) {
        free(model->memory);
        free(model);
        return MEMORY_MODEL_ERROR_OUT_OF_MEMORY;
    }

    memory_model_error_t reset_status = memory_model_reset(model);
    if (reset_status != MEMORY_MODEL_ERROR_OK) {
        memory_model_destroy(model);
        return reset_status;
    }

    *model_out = model;
    return MEMORY_MODEL_ERROR_OK;
}

void memory_model_destroy(memory_model_t *model)
{
    if (model == NULL) {
        return;
    }

    free(model->tlb);
    free(model->memory);
    free(model);
}

memory_model_error_t memory_model_reset(memory_model_t *model)
{
    if (model == NULL) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }

    size_t total_bytes = (size_t)model->cfg.mem_depth * (size_t)model->bytes_per_word;
    if (model->memory != NULL && total_bytes > 0U) {
        memset(model->memory, 0, total_bytes);
    }
    if (model->tlb != NULL && model->cfg.tlb_entries > 0U) {
        memset(model->tlb, 0, sizeof(struct tlb_entry) * (size_t)model->cfg.tlb_entries);
    }

    model->tlb_write_ptr = 0U;
    model->active_entries = 0U;

    return MEMORY_MODEL_ERROR_OK;
}

memory_model_error_t memory_model_load_tlb(memory_model_t *model,
                                           uint64_t virt_base,
                                           uint64_t phys_base)
{
    if (model == NULL || model->tlb == NULL || model->cfg.tlb_entries == 0U) {
        return MEMORY_MODEL_ERROR_BAD_ARGUMENT;
    }

    uint32_t index = model->tlb_write_ptr;
    struct tlb_entry *entry = &model->tlb[index];

    bool was_valid = entry->valid;
    entry->valid = true;
    entry->virt_base = virt_base & model->virt_addr_mask;
    entry->phys_base = phys_base & model->phys_addr_mask;

    if (!was_valid && model->active_entries < model->cfg.tlb_entries) {
        model->active_entries++;
    }

    if (index + 1U < model->cfg.tlb_entries) {
        model->tlb_write_ptr = index + 1U;
    } else {
        model->tlb_write_ptr = 0U;
    }

    return MEMORY_MODEL_ERROR_OK;
}

memory_model_status_t memory_model_translate(const memory_model_t *model,
                                              uint64_t virt_addr,
                                              uint64_t *phys_addr_out)
{
    if (phys_addr_out == NULL || model == NULL) {
        if (phys_addr_out != NULL) {
            *phys_addr_out = 0ULL;
        }
        return MEMORY_MODEL_STATUS_ERR_ACCESS;
    }

    uint64_t masked_virt = virt_addr & model->virt_addr_mask;
    uint64_t virt_page = masked_virt >> model->page_offset_bits;
    uint64_t page_offset = masked_virt & model->page_offset_mask;

    for (uint32_t i = 0U; i < model->cfg.tlb_entries; ++i) {
        const struct tlb_entry *entry = &model->tlb[i];
        if (!entry->valid) {
            continue;
        }

        uint64_t entry_page = (entry->virt_base & model->virt_addr_mask) >> model->page_offset_bits;
        if (entry_page == virt_page) {
            uint64_t phys_base = entry->phys_base & model->phys_addr_mask;
            uint64_t combined = (phys_base & ~model->page_offset_mask) | page_offset;
            *phys_addr_out = combined & model->phys_addr_mask;
            return MEMORY_MODEL_STATUS_OK;
        }
    }

    *phys_addr_out = 0ULL;
    return MEMORY_MODEL_STATUS_ERR_ADDR;
}

memory_model_status_t memory_model_read(const memory_model_t *model,
                                         uint64_t virt_addr,
                                         uint32_t byte_mask,
                                         uint64_t *data_out)
{
    if (data_out == NULL || model == NULL) {
        if (data_out != NULL) {
            *data_out = 0ULL;
        }
        return MEMORY_MODEL_STATUS_ERR_ACCESS;
    }

    uint32_t valid_mask = byte_mask_for_word(model->bytes_per_word);
    if ((byte_mask & ~valid_mask) != 0U) {
        *data_out = 0ULL;
        return MEMORY_MODEL_STATUS_ERR_ACCESS;
    }

    uint32_t effective_mask = byte_mask;
    if (effective_mask == 0U) {
        effective_mask = valid_mask;
    }

    uint64_t phys_addr = 0ULL;
    memory_model_status_t translate_status = memory_model_translate(model, virt_addr, &phys_addr);
    if (translate_status != MEMORY_MODEL_STATUS_OK) {
        *data_out = 0ULL;
        return translate_status;
    }

    size_t mem_index = (size_t)(phys_addr & model->mem_addr_mask);
    if (!model->mem_depth_pow2 && mem_index >= model->cfg.mem_depth) {
        *data_out = 0ULL;
        return MEMORY_MODEL_STATUS_ERR_ACCESS;
    }

    size_t offset = mem_index * (size_t)model->bytes_per_word;
    uint64_t value = 0ULL;

    for (uint32_t i = 0U; i < model->bytes_per_word; ++i) {
        if ((effective_mask & (1U << i)) == 0U) {
            continue;
        }
        uint64_t byte_val = (uint64_t)model->memory[offset + i];
        value |= byte_val << (i * 8U);
    }

    value &= model->data_mask;
    *data_out = value;
    return MEMORY_MODEL_STATUS_OK;
}

memory_model_status_t memory_model_write(memory_model_t *model,
                                          uint64_t virt_addr,
                                          uint32_t byte_mask,
                                          uint64_t data)
{
    if (model == NULL) {
        return MEMORY_MODEL_STATUS_ERR_ACCESS;
    }

    uint32_t valid_mask = byte_mask_for_word(model->bytes_per_word);
    if ((byte_mask & ~valid_mask) != 0U) {
        return MEMORY_MODEL_STATUS_ERR_WRITE;
    }

    uint64_t phys_addr = 0ULL;
    memory_model_status_t translate_status = memory_model_translate(model, virt_addr, &phys_addr);
    if (translate_status != MEMORY_MODEL_STATUS_OK) {
        return translate_status;
    }

    if (byte_mask == 0U) {
        return MEMORY_MODEL_STATUS_OK;
    }

    size_t mem_index = (size_t)(phys_addr & model->mem_addr_mask);
    if (!model->mem_depth_pow2 && mem_index >= model->cfg.mem_depth) {
        return MEMORY_MODEL_STATUS_ERR_ACCESS;
    }

    size_t offset = mem_index * (size_t)model->bytes_per_word;
    uint64_t masked_data = data & model->data_mask;

    for (uint32_t i = 0U; i < model->bytes_per_word; ++i) {
        if ((byte_mask & (1U << i)) == 0U) {
            continue;
        }
        uint8_t byte_value = (uint8_t)((masked_data >> (i * 8U)) & 0xFFU);
        model->memory[offset + i] = byte_value;
    }

    return MEMORY_MODEL_STATUS_OK;
}

uint32_t memory_model_active_entries(const memory_model_t *model)
{
    if (model == NULL) {
        return 0U;
    }
    return model->active_entries;
}

uint32_t memory_model_tlb_write_index(const memory_model_t *model)
{
    if (model == NULL) {
        return 0U;
    }
    return model->tlb_write_ptr;
}

uint32_t memory_model_tlb_capacity(const memory_model_t *model)
{
    if (model == NULL) {
        return 0U;
    }
    return model->cfg.tlb_entries;
}

const memory_model_config_t *memory_model_get_config(const memory_model_t *model)
{
    if (model == NULL) {
        return NULL;
    }
    return &model->cfg;
}
