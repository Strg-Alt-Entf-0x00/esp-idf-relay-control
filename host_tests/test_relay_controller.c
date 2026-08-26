#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "esp_err.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "driver/gpio.h"

static int64_t fake_time_us;
static unsigned gpio_config_calls;
static unsigned gpio_levels[49];

typedef struct {
    unsigned length;
    unsigned count;
    unsigned item_size;
    unsigned char item[128];
} fake_queue_t;

static StaticSemaphore_t fake_binary_storage;

int gpio_config(const gpio_config_t *config)
{
    (void)config;
    gpio_config_calls++;
    return ESP_OK;
}

int gpio_set_level(gpio_num_t gpio, unsigned level)
{
    if (gpio >= 0 && gpio < 49) gpio_levels[gpio] = level;
    return ESP_OK;
}

int64_t esp_timer_get_time(void)
{
    return fake_time_us;
}

QueueHandle_t xQueueCreate(unsigned length, unsigned item_size)
{
    fake_queue_t *queue = calloc(1, sizeof(*queue));
    if (!queue || item_size > sizeof(queue->item)) return NULL;
    queue->length = length;
    queue->item_size = item_size;
    return queue;
}

BaseType_t xQueueSend(QueueHandle_t handle, const void *item, TickType_t wait)
{
    fake_queue_t *queue = handle;
    (void)wait;
    if (queue->count >= queue->length) {
        if (wait == portMAX_DELAY) return pdTRUE;
        return pdFALSE;
    }
    memcpy(queue->item, item, queue->item_size);
    queue->count++;
    return pdTRUE;
}

BaseType_t xQueueReceive(QueueHandle_t handle, void *item, TickType_t wait)
{
    fake_queue_t *queue = handle;
    (void)wait;
    if (queue->count == 0) return pdFALSE;
    memcpy(item, queue->item, queue->item_size);
    queue->count = 0;
    return pdTRUE;
}

void vQueueDelete(QueueHandle_t handle)
{
    free(handle);
}

BaseType_t xTaskCreate(TaskFunction_t task, const char *name, unsigned stack_size,
                       void *arg, unsigned priority, TaskHandle_t *handle)
{
    (void)task;
    (void)name;
    (void)stack_size;
    (void)arg;
    (void)priority;
    *handle = (TaskHandle_t)(uintptr_t)2;
    return pdPASS;
}

void vTaskDelete(TaskHandle_t task)
{
    (void)task;
}

void vTaskDelay(TickType_t ticks)
{
    (void)ticks;
}

TaskHandle_t xTaskGetCurrentTaskHandle(void)
{
    return (TaskHandle_t)(uintptr_t)1;
}

SemaphoreHandle_t xSemaphoreCreateMutexStatic(StaticSemaphore_t *storage)
{
    return storage;
}

SemaphoreHandle_t xSemaphoreCreateBinary(void)
{
    return &fake_binary_storage;
}

BaseType_t xSemaphoreTake(SemaphoreHandle_t semaphore, TickType_t wait)
{
    (void)semaphore;
    (void)wait;
    return pdTRUE;
}

BaseType_t xSemaphoreGive(SemaphoreHandle_t semaphore)
{
    (void)semaphore;
    return pdTRUE;
}

void vSemaphoreDelete(SemaphoreHandle_t semaphore)
{
    (void)semaphore;
}

#include "../src/relay_controller.c"

static const relay_channel_config_t test_channels[] = {
    { .gpio = GPIO_NUM_2, .active_level = 1, .initial_state = RELAY_STATE_OFF, .max_on_time_ms = 100 },
    { .gpio = GPIO_NUM_3, .active_level = 0, .initial_state = RELAY_STATE_OFF, .max_on_time_ms = 0 },
};

static void reset_stubs(void)
{
    fake_time_us = 0;
    gpio_config_calls = 0;
    memset(gpio_levels, 0, sizeof(gpio_levels));
}

static void test_validation(void)
{
    relay_channel_config_t duplicate_channels[] = {
        { .gpio = GPIO_NUM_2, .active_level = 1, .initial_state = RELAY_STATE_OFF },
        { .gpio = GPIO_NUM_2, .active_level = 1, .initial_state = RELAY_STATE_OFF },
    };
    reset_stubs();
    assert(relay_controller_init(NULL) == ESP_ERR_INVALID_ARG);
    assert(relay_controller_init(&(relay_controller_config_t){
        .channels = duplicate_channels,
        .channel_count = 2,
    }) == ESP_ERR_INVALID_ARG);
    assert(gpio_config_calls == 0);
    assert(relay_controller_set(0, RELAY_STATE_ON) == ESP_ERR_INVALID_STATE);
}

static void test_queue_overflow_and_reinit(void)
{
    reset_stubs();
    assert(relay_controller_init(&(relay_controller_config_t){
        .channels = test_channels,
        .channel_count = 2,
        .queue_length = 1,
    }) == ESP_OK);
    assert(relay_controller_init(&(relay_controller_config_t){
        .channels = test_channels,
        .channel_count = 2,
    }) == ESP_ERR_INVALID_STATE);
    assert(relay_controller_set(0, RELAY_STATE_ON) == ESP_OK);
    assert(relay_controller_set(1, RELAY_STATE_ON) == ESP_ERR_TIMEOUT);
    assert(relay_controller_deinit() == ESP_OK);
    assert(relay_controller_deinit() == ESP_OK);
    assert(relay_controller_set(0, RELAY_STATE_ON) == ESP_ERR_INVALID_STATE);
}

int main(void)
{
    test_validation();
    test_queue_overflow_and_reinit();
    puts("relay_controller host tests: PASS");
    return 0;
}
