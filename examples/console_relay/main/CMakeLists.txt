idf_component_register(
    SRCS "app_main.c"
    INCLUDE_DIRS "."
    REQUIRES console esp_driver_gpio nvs_flash relay_control
)