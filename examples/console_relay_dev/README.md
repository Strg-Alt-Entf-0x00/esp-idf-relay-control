# ESP32-P4 relay console example

This ESP-IDF example exposes the complete relay controller through the UART console
and is configured for an ESP32-P4 with 32 MB QIO flash. The checked-in
`sdkconfig.defaults` supports ESP32-P4 revision 1.3 and all other revisions
selected by the ESP-IDF 6.0.2 configuration.

```text
help
list                         show the configured channels
status                       show state and remaining time
on <channel>                 switch a channel on
off <channel>                switch a channel off
pulse <channel> <duration>   pulse for duration in milliseconds
toggle <channel>             toggle a channel
stop <channel>               stop a pulse and switch off
all_off                      switch every channel off
```

Both channels use active-low inputs: channel 0 uses GPIO 32 and a 5-second
safety timeout; channel 1 uses GPIO 33 and has no automatic timeout. The
channel LEDs should indicate when their respective relays are energized.
Verify the board markings and wiring before connecting a load.

The defaults also select a 360 MHz CPU and 32 MB QIO flash. They do not replace
the board's electrical requirements or a board-specific partition table.

Build and monitor from this directory:

```text
idf.py set-target esp32p4
idf.py build
idf.py flash monitor
```

The example requires ESP-IDF 6.0.2 or a compatible ESP-IDF release. Use the
serial port of the connected ESP32-P4 for flashing and monitoring, for example:

```text
idf.py -p COM5 flash monitor
```