idf_component_register(
    SRCS "test_relay_controller.c"
    INCLUDE_DIRS "."
    REQUIRES unity esp_driver_gpio freertos esp-relay-control
)
