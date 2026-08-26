#include "unity.h"
#include "unity_test_runner.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "relay_controller.h"

static volatile unsigned state_changed_count;
static volatile unsigned pulse_complete_count;
static volatile unsigned timeout_count;

static void relay_event(const relay_event_t *event, void *context)
{
    (void)context;
    if (event->type == RELAY_EVENT_STATE_CHANGED) state_changed_count++;
    if (event->type == RELAY_EVENT_PULSE_COMPLETE) pulse_complete_count++;
    if (event->type == RELAY_EVENT_TIMEOUT) timeout_count++;
}

static const relay_channel_config_t test_channels[] = {
    { .gpio = GPIO_NUM_2, .active_level = 1, .initial_state = RELAY_STATE_OFF, .max_on_time_ms = 150 },
    { .gpio = GPIO_NUM_3, .active_level = 0, .initial_state = RELAY_STATE_OFF, .max_on_time_ms = 0 },
};

static void wait_ms(uint32_t milliseconds)
{
    vTaskDelay(pdMS_TO_TICKS(milliseconds));
}

void setUp(void)
{
    state_changed_count = 0;
    pulse_complete_count = 0;
    timeout_count = 0;
}

void tearDown(void)
{
    relay_controller_deinit();
}

TEST_CASE("rejects invalid arguments before initialization", "relay_controller")
{
    TEST_ASSERT_EQUAL(ESP_ERR_INVALID_ARG, relay_controller_init(NULL));
    TEST_ASSERT_EQUAL(ESP_ERR_INVALID_STATE, relay_controller_set(0, RELAY_STATE_ON));
    TEST_ASSERT_EQUAL(ESP_ERR_INVALID_ARG, relay_controller_pulse(0, 0));
}

TEST_CASE("initializes and reports channels", "relay_controller")
{
    size_t channel_count = 0;
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_init(&(relay_controller_config_t){
        .channels = test_channels,
        .channel_count = 2,
    }));
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_get_channel_count(&channel_count));
    TEST_ASSERT_EQUAL_UINT(2, channel_count);
}

TEST_CASE("runs a pulse and reports completion", "relay_controller")
{
    relay_state_t state = RELAY_STATE_OFF;
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_init(&(relay_controller_config_t){
        .channels = test_channels,
        .channel_count = 2,
    }));
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_set_callback(relay_event, NULL));
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_pulse(0, 40));
    wait_ms(100);
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_get_state(0, &state));
    TEST_ASSERT_EQUAL(RELAY_STATE_OFF, state);
    TEST_ASSERT_GREATER_OR_EQUAL_UINT(1, pulse_complete_count);
}

TEST_CASE("enforces maximum on time", "relay_controller")
{
    relay_state_t state = RELAY_STATE_OFF;
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_init(&(relay_controller_config_t){
        .channels = test_channels,
        .channel_count = 2,
    }));
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_set_callback(relay_event, NULL));
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_set(0, RELAY_STATE_ON));
    wait_ms(250);
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_get_state(0, &state));
    TEST_ASSERT_EQUAL(RELAY_STATE_OFF, state);
    TEST_ASSERT_GREATER_OR_EQUAL_UINT(1, timeout_count);
}

TEST_CASE("toggle, stop, and all_off control channels", "relay_controller")
{
    relay_state_t state = RELAY_STATE_OFF;
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_init(&(relay_controller_config_t){
        .channels = test_channels,
        .channel_count = 2,
    }));
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_toggle(1));
    wait_ms(30);
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_get_state(1, &state));
    TEST_ASSERT_EQUAL(RELAY_STATE_ON, state);
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_all_off());
    wait_ms(30);
    TEST_ASSERT_EQUAL(ESP_OK, relay_controller_get_state(1, &state));
    TEST_ASSERT_EQUAL(RELAY_STATE_OFF, state);
}

void app_main(void)
{
    unity_run_all_tests();
}
