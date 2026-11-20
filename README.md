# ESP-IDF Relay Controller

Non-blocking GPIO relay control for ESP-IDF. The component supports multiple
independent channels, parallel pulses, active-high or active-low relay modules,
and optional automatic off limits.

## Basic use

```c
#include "relay_controller.h"

static const relay_channel_config_t channels[] = {
    {
        .gpio = GPIO_NUM_32,
        .active_level = 0,
        .initial_state = RELAY_STATE_OFF,
        .max_on_time_ms = 0,
    },
    {
        .gpio = GPIO_NUM_33,
        .active_level = 0,
        .initial_state = RELAY_STATE_OFF,
        .max_on_time_ms = 10000,
    },
};

relay_controller_init(&(relay_controller_config_t){
    .channels = channels,
    .channel_count = 2,
});

relay_controller_set(0, RELAY_STATE_ON);  // No timeout when max_on_time_ms is 0
relay_controller_pulse(1, 300);           // Runs independently of channel 0
```

All public operations are non-blocking. Commands are queued and executed by a
dedicated task, so pulses on different channels can overlap. A configured
`max_on_time_ms` of zero disables the automatic limit. A nonzero value caps
the maximum ON duration for that channel.

The callback receives state changes and pulse completion events:

```c
static void relay_event(const relay_event_t *event, void *context)
{
    (void)context;
    if (event->type == RELAY_EVENT_PULSE_COMPLETE) {
        // The pulse on event->channel has finished.
    }
}

relay_controller_set_callback(relay_event, NULL);
```

## API contract

All controller operations are serialized with initialization and deinitialization
and may be called from normal FreeRTOS tasks. They are not ISR-safe. Commands
are queued without waiting; `ESP_ERR_TIMEOUT` means the command queue is full.
The callback runs on the controller task, so it must be short and non-blocking.
Do not call `relay_controller_deinit()` from the callback.

`relay_controller_deinit()` waits for already queued commands, switches all
configured outputs to their inactive level, stops the worker task, and releases
the queue. A failed initialization switches off every GPIO configured before the
failure and leaves the controller ready for another initialization attempt.

## Hardware acceptance test

With the console example running, verify the following sequence for each wired
channel. Use a multimeter or the relay board indicator, and never connect mains
voltage during software bring-up:

```text
status
on 0
status
off 0
pulse 0 1000
status
toggle 1
status
stop 1
all_off
status
```

For a channel with `max_on_time_ms`, issue a pulse longer than the limit and
verify that the event is reported as `TIMEOUT` and the output turns off.

## Integration

The repository root is the component. Add it to a project with the ESP-IDF
Component Manager or copy the repository into the project's `components`
directory. The component requires
ESP-IDF 5.0 or newer and only depends on the GPIO, timer, FreeRTOS, and logging
APIs.

The repository CI is pinned to ESP-IDF 6.0.2. Local builds should use the same
ESP-IDF release when reproducing CI results.

The component does not assume a specific board, relay module, PC protocol, or
display. Electrical protection, relay power supply, and mains safety remain
part of the hardware design.

## Example

The [Waveshare ESP32-P4-WIFI6 console example](examples/ws-esp32-p4-wifi6-console_relay_dev)
exposes the relay controller through the UART console using GPIOs 32 and 33.
It does not use the board's Wi-Fi coprocessor. Open that directory as the
ESP-IDF project before building or flashing it, and verify the pinout and
relay-module wiring for the board revision.

## Tests

The ESP-IDF Unity test application is in
[`test_apps/relay_controller`](test_apps/relay_controller/README.md). It runs
six Unity tests on an ESP32-P4, covering argument validation,
initialization/reinitialization, pulse completion, safety timeouts, callbacks,
toggle, stop, and `all_off`. The test app drives GPIOs 2 and 3; see its README
for safe hardware setup.