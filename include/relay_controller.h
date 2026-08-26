#ifndef RELAY_CONTROLLER_H
#define RELAY_CONTROLLER_H

#include "driver/gpio.h"
#include "esp_err.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RELAY_CONTROLLER_MAX_CHANNELS 16

typedef enum {
	RELAY_STATE_OFF = 0,
	RELAY_STATE_ON,
} relay_state_t;

typedef struct {
	gpio_num_t gpio;
	uint8_t active_level;
	relay_state_t initial_state;
	uint32_t max_on_time_ms;
} relay_channel_config_t;

typedef struct {
	const relay_channel_config_t *channels;
	size_t channel_count;
	uint8_t queue_length;
	uint16_t task_stack_size;
	uint8_t task_priority;
} relay_controller_config_t;

typedef enum {
	RELAY_EVENT_STATE_CHANGED,
	RELAY_EVENT_PULSE_COMPLETE,
	RELAY_EVENT_TIMEOUT,
} relay_event_type_t;

typedef struct {
	relay_event_type_t type;
	size_t channel;
	relay_state_t state;
	bool success;
	uint32_t duration_ms;
} relay_event_t;

typedef void (*relay_event_callback_t)(const relay_event_t *event, void *user_context);

esp_err_t relay_controller_init(const relay_controller_config_t *config);
esp_err_t relay_controller_deinit(void);
esp_err_t relay_controller_set_callback(relay_event_callback_t callback, void *user_context);
esp_err_t relay_controller_set(size_t channel, relay_state_t state);
esp_err_t relay_controller_pulse(size_t channel, uint32_t duration_ms);
esp_err_t relay_controller_toggle(size_t channel);
esp_err_t relay_controller_stop(size_t channel);
esp_err_t relay_controller_all_off(void);
esp_err_t relay_controller_get_channel_count(size_t *channel_count);
esp_err_t relay_controller_get_remaining_ms(size_t channel, uint32_t *remaining_ms);
esp_err_t relay_controller_get_state(size_t channel, relay_state_t *state);
bool relay_controller_is_busy(size_t channel);

#ifdef __cplusplus
}
#endif

#endif
