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

## Integration

The repository root is the component. Add it to a project with the ESP-IDF
Component Manager or copy the repository into the project's `components`
directory. The component requires
ESP-IDF 5.0 or newer and only depends on the GPIO, timer, FreeRTOS, and logging
APIs.

The component does not assume a specific board, relay module, PC protocol, or
display. Electrical protection, relay power supply, and mains safety remain
part of the hardware design.

## Example

The [console example](examples/console_relay) exposes the complete relay
controller through the UART console. Open that directory as the ESP-IDF project
before building or flashing it.