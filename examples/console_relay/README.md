# Relay console example

This ESP-IDF example exposes the complete relay controller through the UART console.

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

Channel 0 uses active-high GPIO 2 and a 5-second safety timeout. Channel 1 uses
active-low GPIO 3 and has no automatic timeout. Adjust the GPIOs in
`main/app_main.c` for the target board before connecting hardware.

Build and monitor from this directory:

```text
idf.py set-target esp32p4
idf.py build
idf.py flash monitor
```