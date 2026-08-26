#ifndef DRIVER_GPIO_H
#define DRIVER_GPIO_H

#include <stdint.h>

typedef int gpio_num_t;
#define GPIO_NUM_0 0
#define GPIO_NUM_2 2
#define GPIO_NUM_3 3
#define GPIO_NUM_4 4
#define GPIO_NUM_5 5
#define GPIO_NUM_32 32
#define GPIO_NUM_33 33
#define GPIO_IS_VALID_OUTPUT_GPIO(gpio) ((gpio) >= 0 && (gpio) <= 48)

typedef enum { GPIO_MODE_OUTPUT = 1 } gpio_mode_t;
typedef enum { GPIO_PULLUP_DISABLE = 0 } gpio_pullup_t;
typedef enum { GPIO_PULLDOWN_DISABLE = 0 } gpio_pulldown_t;
typedef enum { GPIO_INTR_DISABLE = 0 } gpio_int_type_t;
typedef struct {
    uint64_t pin_bit_mask;
    gpio_mode_t mode;
    gpio_pullup_t pull_up_en;
    gpio_pulldown_t pull_down_en;
    gpio_int_type_t intr_type;
} gpio_config_t;

int gpio_config(const gpio_config_t *config);
int gpio_set_level(gpio_num_t gpio, unsigned level);

#endif
