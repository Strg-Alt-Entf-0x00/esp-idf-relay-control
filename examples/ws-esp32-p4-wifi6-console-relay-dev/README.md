# Waveshare ESP32-P4-WIFI6 relay console example

This development example exposes the relay controller through the UART console
and targets the [Waveshare ESP32-P4-WIFI6 board](https://docs.waveshare.com/ESP32-P4-WIFI6).
It uses the ESP32-P4 UART and GPIOs 32 and 33; it does not configure or use the
board's ESP32-C6 Wi-Fi coprocessor.

The checked-in `sdkconfig.defaults` selects the ESP32-P4 target and 32 MB QIO
flash. Use ESP-IDF 6.0.2 or a compatible release.

Connect compatible active-low relay inputs to GPIOs 32 and 33. Verify the
board revision, pinout, relay module, and wiring before connecting a load.

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

The outputs are active-low: channel 0 uses GPIO 32 and has a 5-second safety
timeout; channel 1 uses GPIO 33 and has no automatic timeout.

Build and monitor from this directory:

```text
idf.py set-target esp32p4
idf.py build
idf.py flash monitor
```

Use the serial port of the connected board for flashing and monitoring, for
example:

```text
idf.py -p COM5 flash monitor
```