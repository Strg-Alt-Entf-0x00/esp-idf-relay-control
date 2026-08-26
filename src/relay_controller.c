#include "relay_controller.h"

#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/portmacro.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include <string.h>

static const char *TAG = "RELAY_CTRL";
#define DEFAULT_QUEUE_LENGTH 8
#define DEFAULT_TASK_STACK 3072
#define DEFAULT_TASK_PRIORITY 5
#define POLL_INTERVAL_MS 10

typedef enum { COMMAND_SET, COMMAND_PULSE, COMMAND_TOGGLE, COMMAND_ALL_OFF } command_type_t;
typedef struct {
    command_type_t type;
    size_t channel;
    relay_state_t state;
    uint32_t duration_ms;
} controller_command_t;

typedef struct {
    relay_channel_config_t config[RELAY_CONTROLLER_MAX_CHANNELS];
    relay_state_t state[RELAY_CONTROLLER_MAX_CHANNELS];
    int64_t off_at_us[RELAY_CONTROLLER_MAX_CHANNELS];
    uint32_t pulse_duration_ms[RELAY_CONTROLLER_MAX_CHANNELS];
    bool safety_timeout[RELAY_CONTROLLER_MAX_CHANNELS];
    QueueHandle_t queue;
    TaskHandle_t task;
    relay_event_callback_t callback;
    void *callback_context;
    size_t channel_count;
    bool initialized;
} relay_controller_state_t;

static relay_controller_state_t s_controller;
static portMUX_TYPE s_state_lock = portMUX_INITIALIZER_UNLOCKED;

static void clear_timer(size_t channel)
{
    portENTER_CRITICAL(&s_state_lock);
    s_controller.off_at_us[channel] = 0;
    s_controller.safety_timeout[channel] = false;
    portEXIT_CRITICAL(&s_state_lock);
}

static void set_timer(size_t channel, int64_t deadline, uint32_t duration_ms, bool safety_timeout)
{
    portENTER_CRITICAL(&s_state_lock);
    s_controller.off_at_us[channel] = deadline;
    s_controller.pulse_duration_ms[channel] = duration_ms;
    s_controller.safety_timeout[channel] = safety_timeout;
    portEXIT_CRITICAL(&s_state_lock);
}

static bool expire_timer(size_t channel, int64_t now_us, bool *safety_timeout)
{
    bool expired = false;
    portENTER_CRITICAL(&s_state_lock);
    if (s_controller.off_at_us[channel] != 0 && now_us >= s_controller.off_at_us[channel]) {
        s_controller.off_at_us[channel] = 0;
        *safety_timeout = s_controller.safety_timeout[channel];
        s_controller.safety_timeout[channel] = false;
        expired = true;
    }
    portEXIT_CRITICAL(&s_state_lock);
    return expired;
}

static void notify(size_t channel, relay_event_type_t type, bool success)
{
    relay_event_callback_t callback;
    void *callback_context;
    relay_event_t event = {
        .type = type,
        .channel = channel,
        .success = success,
    };
    portENTER_CRITICAL(&s_state_lock);
    callback = s_controller.callback;
    callback_context = s_controller.callback_context;
    event.state = s_controller.state[channel];
    event.duration_ms = s_controller.pulse_duration_ms[channel];
    portEXIT_CRITICAL(&s_state_lock);
    if (callback) callback(&event, callback_context);
}

static void write_state(size_t channel, relay_state_t state)
{
    const relay_channel_config_t *config = &s_controller.config[channel];
    int level = state == RELAY_STATE_ON ? config->active_level : !config->active_level;
    gpio_set_level(config->gpio, level);
    bool changed;
    portENTER_CRITICAL(&s_state_lock);
    changed = s_controller.state[channel] != state;
    s_controller.state[channel] = state;
    portEXIT_CRITICAL(&s_state_lock);
    if (changed) {
        notify(channel, RELAY_EVENT_STATE_CHANGED, true);
    }
}

static void controller_task(void *argument)
{
    (void)argument;
    controller_command_t command;
    while (true) {
        while (xQueueReceive(s_controller.queue, &command, 0) == pdTRUE) {
            if (command.type == COMMAND_ALL_OFF) {
                for (size_t channel = 0; channel < s_controller.channel_count; channel++) {
                    clear_timer(channel);
                    write_state(channel, RELAY_STATE_OFF);
                }
                continue;
            }
            if (command.channel >= s_controller.channel_count) continue;
            if (command.type == COMMAND_TOGGLE) {
                clear_timer(command.channel);
                relay_state_t current_state;
                portENTER_CRITICAL(&s_state_lock);
                current_state = s_controller.state[command.channel];
                portEXIT_CRITICAL(&s_state_lock);
                write_state(command.channel, current_state == RELAY_STATE_ON ?
                            RELAY_STATE_OFF : RELAY_STATE_ON);
            } else if (command.type == COMMAND_SET) {
                write_state(command.channel, command.state);
                if (command.state == RELAY_STATE_ON &&
                    s_controller.config[command.channel].max_on_time_ms != 0) {
                    uint32_t maximum = s_controller.config[command.channel].max_on_time_ms;
                    set_timer(command.channel, esp_timer_get_time() + (int64_t)maximum * 1000,
                              maximum, true);
                } else {
                    clear_timer(command.channel);
                }
            } else {
                uint32_t duration_ms = command.duration_ms;
                uint32_t maximum = s_controller.config[command.channel].max_on_time_ms;
                bool safety_timeout = maximum != 0 && duration_ms > maximum;
                if (maximum != 0 && duration_ms > maximum) duration_ms = maximum;
                write_state(command.channel, RELAY_STATE_ON);
                set_timer(command.channel, esp_timer_get_time() + (int64_t)duration_ms * 1000,
                          duration_ms, safety_timeout);
            }
        }

        int64_t now_us = esp_timer_get_time();
        for (size_t channel = 0; channel < s_controller.channel_count; channel++) {
            bool safety_timeout = false;
            if (expire_timer(channel, now_us, &safety_timeout)) {
                write_state(channel, RELAY_STATE_OFF);
                notify(channel, safety_timeout ? RELAY_EVENT_TIMEOUT : RELAY_EVENT_PULSE_COMPLETE, true);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(POLL_INTERVAL_MS));
    }
}

static esp_err_t queue_command(controller_command_t command)
{
    if (!s_controller.initialized) return ESP_ERR_INVALID_STATE;
    if (command.channel >= s_controller.channel_count) return ESP_ERR_INVALID_ARG;
    return xQueueSend(s_controller.queue, &command, 0) == pdTRUE ? ESP_OK : ESP_ERR_TIMEOUT;
}

esp_err_t relay_controller_init(const relay_controller_config_t *config)
{
    if (!config || !config->channels || config->channel_count == 0 ||
        config->channel_count > RELAY_CONTROLLER_MAX_CHANNELS) return ESP_ERR_INVALID_ARG;
    if (s_controller.initialized) return ESP_ERR_INVALID_STATE;

    for (size_t channel = 0; channel < config->channel_count; channel++) {
        const relay_channel_config_t *channel_config = &config->channels[channel];
        if (!GPIO_IS_VALID_OUTPUT_GPIO(channel_config->gpio) ||
            channel_config->active_level > 1 || channel_config->initial_state > RELAY_STATE_ON) {
            return ESP_ERR_INVALID_ARG;
        }
        for (size_t previous = 0; previous < channel; previous++) {
            if (config->channels[previous].gpio == channel_config->gpio) {
                return ESP_ERR_INVALID_ARG;
            }
        }
    }

    memset(&s_controller, 0, sizeof(s_controller));
    s_controller.channel_count = config->channel_count;
    memcpy(s_controller.config, config->channels,
           config->channel_count * sizeof(relay_channel_config_t));

    for (size_t channel = 0; channel < s_controller.channel_count; channel++) {
        const relay_channel_config_t *channel_config = &s_controller.config[channel];
        gpio_config_t gpio_configuration = {
            .pin_bit_mask = 1ULL << channel_config->gpio,
            .mode = GPIO_MODE_OUTPUT,
            .pull_up_en = GPIO_PULLUP_DISABLE,
            .pull_down_en = GPIO_PULLDOWN_DISABLE,
            .intr_type = GPIO_INTR_DISABLE,
        };
        esp_err_t ret = gpio_config(&gpio_configuration);
        if (ret != ESP_OK) return ret;
        s_controller.state[channel] = channel_config->initial_state;
        write_state(channel, channel_config->initial_state);
    }

    uint8_t queue_length = config->queue_length ? config->queue_length : DEFAULT_QUEUE_LENGTH;
    uint16_t stack_size = config->task_stack_size ? config->task_stack_size : DEFAULT_TASK_STACK;
    uint8_t priority = config->task_priority ? config->task_priority : DEFAULT_TASK_PRIORITY;
    s_controller.queue = xQueueCreate(queue_length, sizeof(controller_command_t));
    if (!s_controller.queue) return ESP_ERR_NO_MEM;
    if (xTaskCreate(controller_task, "relay_controller", stack_size, NULL, priority,
                    &s_controller.task) != pdPASS) {
        vQueueDelete(s_controller.queue);
        s_controller.queue = NULL;
        return ESP_ERR_NO_MEM;
    }
    s_controller.initialized = true;
    ESP_LOGI(TAG, "Initialized %u relay channel(s)", (unsigned)s_controller.channel_count);
    return ESP_OK;
}

esp_err_t relay_controller_deinit(void)
{
    if (!s_controller.initialized) return ESP_OK;
    vTaskDelete(s_controller.task);
    for (size_t channel = 0; channel < s_controller.channel_count; channel++) {
        gpio_set_level(s_controller.config[channel].gpio,
                       !s_controller.config[channel].active_level);
    }
    vQueueDelete(s_controller.queue);
    memset(&s_controller, 0, sizeof(s_controller));
    return ESP_OK;
}

esp_err_t relay_controller_set_callback(relay_event_callback_t callback, void *user_context)
{
    if (!s_controller.initialized) return ESP_ERR_INVALID_STATE;
    portENTER_CRITICAL(&s_state_lock);
    s_controller.callback = callback;
    s_controller.callback_context = user_context;
    portEXIT_CRITICAL(&s_state_lock);
    return ESP_OK;
}

esp_err_t relay_controller_set(size_t channel, relay_state_t state)
{
    if (state > RELAY_STATE_ON) return ESP_ERR_INVALID_ARG;
    return queue_command((controller_command_t){ .type = COMMAND_SET, .channel = channel, .state = state });
}

esp_err_t relay_controller_pulse(size_t channel, uint32_t duration_ms)
{
    if (duration_ms == 0) return ESP_ERR_INVALID_ARG;
    return queue_command((controller_command_t){ .type = COMMAND_PULSE, .channel = channel,
                                                 .duration_ms = duration_ms });
}

esp_err_t relay_controller_get_state(size_t channel, relay_state_t *state)
{
    if (!s_controller.initialized || !state) return ESP_ERR_INVALID_ARG;
    if (channel >= s_controller.channel_count) return ESP_ERR_INVALID_ARG;
    portENTER_CRITICAL(&s_state_lock);
    *state = s_controller.state[channel];
    portEXIT_CRITICAL(&s_state_lock);
    return ESP_OK;
}

bool relay_controller_is_busy(size_t channel)
{
    bool busy = false;
    portENTER_CRITICAL(&s_state_lock);
    if (s_controller.initialized && channel < s_controller.channel_count) {
        busy = s_controller.off_at_us[channel] != 0;
    }
    portEXIT_CRITICAL(&s_state_lock);
    return busy;
}

esp_err_t relay_controller_toggle(size_t channel)
{
    return queue_command((controller_command_t){ .type = COMMAND_TOGGLE, .channel = channel });
}

esp_err_t relay_controller_stop(size_t channel)
{
    return relay_controller_set(channel, RELAY_STATE_OFF);
}

esp_err_t relay_controller_all_off(void)
{
    return queue_command((controller_command_t){ .type = COMMAND_ALL_OFF });
}

esp_err_t relay_controller_get_channel_count(size_t *channel_count)
{
    if (!s_controller.initialized || !channel_count) return ESP_ERR_INVALID_ARG;
    *channel_count = s_controller.channel_count;
    return ESP_OK;
}

esp_err_t relay_controller_get_remaining_ms(size_t channel, uint32_t *remaining_ms)
{
    if (!s_controller.initialized || !remaining_ms) return ESP_ERR_INVALID_ARG;
    if (channel >= s_controller.channel_count) return ESP_ERR_INVALID_ARG;
    portENTER_CRITICAL(&s_state_lock);
    int64_t deadline = s_controller.off_at_us[channel];
    portEXIT_CRITICAL(&s_state_lock);
    if (deadline == 0) {
        *remaining_ms = 0;
        return ESP_OK;
    }
    int64_t remaining_us = deadline - esp_timer_get_time();
    *remaining_ms = remaining_us > 0 ? (uint32_t)((remaining_us + 999) / 1000) : 0;
    return ESP_OK;
}
