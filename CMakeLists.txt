idf_component_register(
	SRCS "src/relay_controller.c"
	INCLUDE_DIRS "include"
	REQUIRES
		esp_driver_gpio
		esp_timer
		freertos
		log
)
