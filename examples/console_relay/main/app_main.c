#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "driver/gpio.h"
#include "esp_console.h"
#include "esp_err.h"
#include "esp_check.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "relay_controller.h"

static const char *TAG = "RELAY_CONSOLE";

static void print_error(esp_err_t error)
{
    if (error != ESP_OK) {
        printf("Error: %s\n", esp_err_to_name(error));
    }
}

static int parse_channel(const char *text, size_t *channel)
{
    char *end = NULL;
    unsigned long value = strtoul(text, &end, 10);
    if (*text == '\0' || *end != '\0' || value >= RELAY_CONTROLLER_MAX_CHANNELS) {
        return -1;
    }
    *channel = (size_t)value;
    return 0;
}

static int require_channel(int argc, char **argv, size_t *channel)
{
    size_t channel_count = 0;
    if (argc != 2 || parse_channel(argv[1], channel) != 0 ||
        relay_controller_get_channel_count(&channel_count) != ESP_OK ||
        *channel >= channel_count) {
        printf("Usage: <command> <channel> (0-%u)\n", (unsigned)(channel_count ? channel_count - 1 : 0));
        return -1;
    }
    return 0;
}

static int console_list(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    size_t channel_count = 0;
    esp_err_t error = relay_controller_get_channel_count(&channel_count);
    if (error != ESP_OK) {
        print_error(error);
        return 1;
    }
    printf("Channels: %u\n", (unsigned)channel_count);
    for (size_t channel = 0; channel < channel_count; channel++) {
        relay_state_t state;
        uint32_t remaining_ms;
        relay_controller_get_state(channel, &state);
        relay_controller_get_remaining_ms(channel, &remaining_ms);
        printf("Channel %u: %s", (unsigned)channel,
               state == RELAY_STATE_ON ? "ON" : "OFF");
        if (remaining_ms) printf(" (remaining %lu ms)", (unsigned long)remaining_ms);
        printf("\n");
    }
    return 0;
}

static int console_set(int argc, char **argv)
{
    size_t channel;
    if (require_channel(argc, argv, &channel) != 0) return 1;
    esp_err_t error = relay_controller_set(channel,
                                            strcmp(argv[0], "on") == 0 ? RELAY_STATE_ON : RELAY_STATE_OFF);
    print_error(error);
    return error == ESP_OK ? 0 : 1;
}

static int console_pulse(int argc, char **argv)
{
    size_t channel;
    char *end = NULL;
    if (argc != 3 || parse_channel(argv[1], &channel) != 0) {
        printf("Usage: pulse <channel> <duration_ms>\n");
        return 1;
    }
    unsigned long duration_ms = strtoul(argv[2], &end, 10);
    if (*argv[2] == '\0' || *end != '\0' || duration_ms > UINT32_MAX) {
        printf("Invalid duration\n");
        return 1;
    }
    esp_err_t error = relay_controller_pulse(channel, (uint32_t)duration_ms);
    print_error(error);
    return error == ESP_OK ? 0 : 1;
}

static int console_toggle(int argc, char **argv)
{
    size_t channel;
    if (require_channel(argc, argv, &channel) != 0) return 1;
    esp_err_t error = relay_controller_toggle(channel);
    print_error(error);
    return error == ESP_OK ? 0 : 1;
}

static int console_stop(int argc, char **argv)
{
    size_t channel;
    if (require_channel(argc, argv, &channel) != 0) return 1;
    esp_err_t error = relay_controller_stop(channel);
    print_error(error);
    return error == ESP_OK ? 0 : 1;
}

static int console_all_off(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    esp_err_t error = relay_controller_all_off();
    print_error(error);
    return error == ESP_OK ? 0 : 1;
}

static void relay_event(const relay_event_t *event, void *context)
{
    (void)context;
    const char *type = event->type == RELAY_EVENT_PULSE_COMPLETE ? "PULSE_COMPLETE" :
                       event->type == RELAY_EVENT_TIMEOUT ? "TIMEOUT" : "STATE_CHANGED";
    ESP_LOGI(TAG, "channel %u: %s (%s)", (unsigned)event->channel, type,
             event->success ? "ok" : "failed");
}

static esp_err_t console_init(void)
{
    static const esp_console_cmd_t commands[] = {
        { .command = "list", .help = "List channels", .func = console_list },
        { .command = "status", .help = "Show channel states and remaining time", .func = console_list },
        { .command = "on", .help = "Turn on: on <channel>", .func = console_set },
        { .command = "off", .help = "Turn off: off <channel>", .func = console_set },
        { .command = "pulse", .help = "Pulse: pulse <channel> <duration_ms>", .func = console_pulse },
        { .command = "toggle", .help = "Toggle: toggle <channel>", .func = console_toggle },
        { .command = "stop", .help = "Stop pulse: stop <channel>", .func = console_stop },
        { .command = "all_off", .help = "Turn all channels off", .func = console_all_off },
    };
    esp_console_repl_t *repl = NULL;
    esp_console_repl_config_t repl_config = ESP_CONSOLE_REPL_CONFIG_DEFAULT();
    esp_console_dev_uart_config_t uart_config = ESP_CONSOLE_DEV_UART_CONFIG_DEFAULT();
    repl_config.prompt = "relay> ";
    ESP_RETURN_ON_ERROR(esp_console_register_help_command(), TAG, "help registration failed");
    for (size_t index = 0; index < sizeof(commands) / sizeof(commands[0]); index++) {
        ESP_RETURN_ON_ERROR(esp_console_cmd_register(&commands[index]), TAG, "command registration failed");
    }
    ESP_RETURN_ON_ERROR(esp_console_new_repl_uart(&uart_config, &repl_config, &repl), TAG, "REPL creation failed");
    return esp_console_start_repl(repl);
}

void app_main(void)
{
    ESP_ERROR_CHECK(nvs_flash_init());
    static const relay_channel_config_t channels[] = {
        { .gpio = GPIO_NUM_2, .active_level = 1, .initial_state = RELAY_STATE_OFF, .max_on_time_ms = 5000 },
        { .gpio = GPIO_NUM_3, .active_level = 0, .initial_state = RELAY_STATE_OFF, .max_on_time_ms = 0 },
    };
    ESP_ERROR_CHECK(relay_controller_init(&(relay_controller_config_t){
        .channels = channels,
        .channel_count = sizeof(channels) / sizeof(channels[0]),
    }));
    ESP_ERROR_CHECK(relay_controller_set_callback(relay_event, NULL));
    ESP_ERROR_CHECK(console_init());
    ESP_LOGI(TAG, "Ready. Type 'help' or 'status'.");
}