#include "memory_model.h"

#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>

static uint64_t mask_width(uint32_t width)
{
    if (width == 0U) {
        return 0ULL;
    }
    if (width >= 64U) {
        return UINT64_MAX;
    }
    return (1ULL << width) - 1ULL;
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

static int test_basic_read_write(void)
{
    int success = 0;
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_basic_read_write: failed to create model\n");
        return 0;
    }

    if (memory_model_load_tlb(model, 0x00001000ULL, 0x00002000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_basic_read_write: failed to load tlb entry\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00001020ULL, 0xFFU, 0x1122334455667788ULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_basic_read_write: write transaction failed\n");
        goto cleanup;
    }

    uint64_t data = 0ULL;
    if (memory_model_read(model, 0x00001020ULL, 0xFFU, &data) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_basic_read_write: read transaction failed\n");
        goto cleanup;
    }

    if (data != 0x1122334455667788ULL) {
        fprintf(stderr, "test_basic_read_write: data mismatch (0x%016" PRIx64 ")\n", data);
        goto cleanup;
    }

    success = 1;

cleanup:
    memory_model_destroy(model);
    return success;
}

static int test_byte_mask_operations(void)
{
    int success = 0;
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_byte_mask_operations: failed to create model\n");
        return 0;
    }

    if (memory_model_load_tlb(model, 0x00000000ULL, 0x00004000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_byte_mask_operations: failed to load tlb entry\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00000010ULL, 0xFFU, 0xFFEEDDCCBBAA9988ULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_byte_mask_operations: initial write failed\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00000010ULL, 0x0FU, 0x1122334455667788ULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_byte_mask_operations: masked write failed\n");
        goto cleanup;
    }

    uint64_t data = 0ULL;
    if (memory_model_read(model, 0x00000010ULL, 0U, &data) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_byte_mask_operations: masked read (full) failed\n");
        goto cleanup;
    }

    if (data != 0xFFEEDDCC55667788ULL) {
        fprintf(stderr, "test_byte_mask_operations: unexpected value after masked write (0x%016" PRIx64 ")\n", data);
        goto cleanup;
    }

    if (memory_model_read(model, 0x00000010ULL, 0x0FU, &data) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_byte_mask_operations: masked read (low) failed\n");
        goto cleanup;
    }

    if (data != 0x0000000055667788ULL) {
        fprintf(stderr, "test_byte_mask_operations: masked read value mismatch (0x%016" PRIx64 ")\n", data);
        goto cleanup;
    }

    success = 1;

cleanup:
    memory_model_destroy(model);
    return success;
}

static int test_missing_translation(void)
{
    int success = 0;
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_missing_translation: failed to create model\n");
        return 0;
    }

    uint64_t data = 1ULL;
    if (memory_model_read(model, 0x00000000ULL, 0xFFU, &data) != MEMORY_MODEL_STATUS_ERR_ADDR) {
        fprintf(stderr, "test_missing_translation: unexpected status for read without mapping\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00000000ULL, 0xFFU, 0x123456789ULL) != MEMORY_MODEL_STATUS_ERR_ADDR) {
        fprintf(stderr, "test_missing_translation: unexpected status for write without mapping\n");
        goto cleanup;
    }

    if (memory_model_load_tlb(model, 0x00000000ULL, 0x00002000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_missing_translation: failed to load tlb entry\n");
        goto cleanup;
    }

    if (memory_model_read(model, 0x00004000ULL, 0xFFU, &data) != MEMORY_MODEL_STATUS_ERR_ADDR) {
        fprintf(stderr, "test_missing_translation: unexpected status for unmapped page\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00000020ULL, 0xFFU, 0xAAAABBBBCCCCDDDDULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_missing_translation: write on mapped page failed\n");
        goto cleanup;
    }

    if (memory_model_read(model, 0x00000020ULL, 0xFFU, &data) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_missing_translation: read on mapped page failed\n");
        goto cleanup;
    }

    if (data != 0xAAAABBBBCCCCDDDDULL) {
        fprintf(stderr, "test_missing_translation: readback mismatch (0x%016" PRIx64 ")\n", data);
        goto cleanup;
    }

    success = 1;

cleanup:
    memory_model_destroy(model);
    return success;
}

static int test_tlb_wraparound(void)
{
    int success = 0;
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();
    cfg.tlb_entries = 4U;

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_tlb_wraparound: failed to create model\n");
        return 0;
    }

    uint64_t phys_mask = mask_width(cfg.phys_addr_width);

    if (memory_model_load_tlb(model, 0x00000000ULL, 0x00001000ULL) != MEMORY_MODEL_ERROR_OK ||
        memory_model_load_tlb(model, 0x00001000ULL, 0x00002000ULL) != MEMORY_MODEL_ERROR_OK ||
        memory_model_load_tlb(model, 0x00002000ULL, 0x00003000ULL) != MEMORY_MODEL_ERROR_OK ||
        memory_model_load_tlb(model, 0x00003000ULL, 0x00004000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_tlb_wraparound: failed to seed tlb entries\n");
        goto cleanup;
    }

    if (memory_model_tlb_write_index(model) != 0U) {
        fprintf(stderr, "test_tlb_wraparound: write pointer did not wrap as expected\n");
        goto cleanup;
    }

    if (memory_model_active_entries(model) != cfg.tlb_entries) {
        fprintf(stderr, "test_tlb_wraparound: active entry count incorrect\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00000034ULL, 0xFFU, 0x1111222233334444ULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_tlb_wraparound: write before overwrite failed\n");
        goto cleanup;
    }

    if (memory_model_load_tlb(model, 0x00000000ULL, 0x00005000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_tlb_wraparound: failed to overwrite entry\n");
        goto cleanup;
    }

    if (memory_model_tlb_write_index(model) != 1U) {
        fprintf(stderr, "test_tlb_wraparound: write pointer incorrect after overwrite\n");
        goto cleanup;
    }

    uint64_t translated = 0ULL;
    if (memory_model_translate(model, 0x00000034ULL, &translated) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_tlb_wraparound: translation failed after overwrite\n");
        goto cleanup;
    }

    uint32_t offset_bits = ceil_log2_u32(cfg.page_size);
    uint64_t offset_mask = mask_width(offset_bits);
    uint64_t expected_phys = ((0x00005000ULL & ~offset_mask) | (0x34ULL & offset_mask)) & phys_mask;
    if (translated != expected_phys) {
        fprintf(stderr,
                "test_tlb_wraparound: expected phys 0x%016" PRIx64 " got 0x%016" PRIx64 "\n",
                expected_phys, translated);
        goto cleanup;
    }

    uint64_t data = 0ULL;
    if (memory_model_read(model, 0x00000034ULL, 0xFFU, &data) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_tlb_wraparound: read after overwrite failed\n");
        goto cleanup;
    }

    if (data != 0ULL) {
        fprintf(stderr, "test_tlb_wraparound: remapped location not zeroed as expected (0x%016" PRIx64 ")\n", data);
        goto cleanup;
    }

    success = 1;

cleanup:
    memory_model_destroy(model);
    return success;
}

static int test_reset_clears_state(void)
{
    int success = 0;
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_reset_clears_state: failed to create model\n");
        return 0;
    }

    if (memory_model_load_tlb(model, 0x00004000ULL, 0x00008000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_reset_clears_state: failed to load tlb\n");
        goto cleanup;
    }

    if (memory_model_write(model, 0x00004010ULL, 0xFFU, 0xCAFEBABECAFED00DULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_reset_clears_state: write failed\n");
        goto cleanup;
    }

    if (memory_model_reset(model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_reset_clears_state: reset failed\n");
        goto cleanup;
    }

    if (memory_model_active_entries(model) != 0U) {
        fprintf(stderr, "test_reset_clears_state: active entries not cleared\n");
        goto cleanup;
    }

    if (memory_model_tlb_write_index(model) != 0U) {
        fprintf(stderr, "test_reset_clears_state: tlb pointer not reset\n");
        goto cleanup;
    }

    uint64_t data = 0ULL;
    if (memory_model_read(model, 0x00004010ULL, 0xFFU, &data) != MEMORY_MODEL_STATUS_ERR_ADDR) {
        fprintf(stderr, "test_reset_clears_state: translation should fail after reset\n");
        goto cleanup;
    }

    success = 1;

cleanup:
    memory_model_destroy(model);
    return success;
}

static int test_translation_preserves_offset(void)
{
    int success = 0;
    memory_model_t *model = NULL;
    memory_model_config_t cfg = memory_model_config_default();

    if (memory_model_create(&cfg, &model) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_translation_preserves_offset: failed to create model\n");
        return 0;
    }

    if (memory_model_load_tlb(model, 0x00002000ULL, 0x00005000ULL) != MEMORY_MODEL_ERROR_OK) {
        fprintf(stderr, "test_translation_preserves_offset: failed to load mapping\n");
        goto cleanup;
    }

    uint64_t phys_addr = 0ULL;
    const uint64_t virt_addr = 0x00002123ULL;
    if (memory_model_translate(model, virt_addr, &phys_addr) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_translation_preserves_offset: translation failed\n");
        goto cleanup;
    }

    uint64_t offset_mask = mask_width(ceil_log2_u32(cfg.page_size));
    uint64_t expected_phys = ((0x00005000ULL & ~offset_mask) | (virt_addr & offset_mask)) & mask_width(cfg.phys_addr_width);
    if (phys_addr != expected_phys) {
        fprintf(stderr, "test_translation_preserves_offset: expected phys 0x%016" PRIx64 " got 0x%016" PRIx64 "\n",
                expected_phys, phys_addr);
        goto cleanup;
    }

    if (memory_model_write(model, virt_addr, 0x03U, 0x000000000000A1B2ULL) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_translation_preserves_offset: masked write failed\n");
        goto cleanup;
    }

    uint64_t data = 0ULL;
    if (memory_model_read(model, virt_addr, 0x03U, &data) != MEMORY_MODEL_STATUS_OK) {
        fprintf(stderr, "test_translation_preserves_offset: masked read failed\n");
        goto cleanup;
    }

    if (data != 0x000000000000A1B2ULL) {
        fprintf(stderr, "test_translation_preserves_offset: readback mismatch (0x%016" PRIx64 ")\n", data);
        goto cleanup;
    }

    success = 1;

cleanup:
    memory_model_destroy(model);
    return success;
}

struct test_case {
    const char *name;
    int (*fn)(void);
};

int main(void)
{
    const struct test_case tests[] = {
        {"basic_read_write", test_basic_read_write},
        {"byte_mask_operations", test_byte_mask_operations},
        {"missing_translation", test_missing_translation},
        {"tlb_wraparound", test_tlb_wraparound},
        {"reset_clears_state", test_reset_clears_state},
        {"translation_preserves_offset", test_translation_preserves_offset},
    };

    const size_t total = sizeof(tests) / sizeof(tests[0]);
    size_t passed = 0U;

    for (size_t i = 0U; i < total; ++i) {
        printf("[ RUN     ] %s\n", tests[i].name);
        if (tests[i].fn()) {
            printf("[     OK ] %s\n", tests[i].name);
            passed++;
        } else {
            printf("[ FAILED ] %s\n", tests[i].name);
        }
    }

    printf("\nSummary: %zu/%zu tests passed.\n", passed, total);
    return passed == total ? 0 : 1;
}
