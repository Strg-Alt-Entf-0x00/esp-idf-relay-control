# Relay controller hardware tests

This ESP-IDF test application runs the relay controller tests on a connected
ESP32-P4 board. It uses GPIO 2 and GPIO 3 as test outputs and is intended for
low-voltage relay hardware only.

Build and run with ESP-IDF 6.0.2 on an ESP32-P4 revision 1.3 board:

```text
idf.py set-target esp32p4
idf.py build
idf.py -p COM4 flash monitor
```

The Unity menu lists five tests. Select tests `1` through `5` individually.
After each test, Unity shows the menu again; pressing ENTER only displays the
menu and does not run all tests. Every selected test must report `PASS` and
`0 Failures`.

The test configuration disables the task watchdog because the interactive
Unity menu waits for UART input. This setting applies only to this test app.
