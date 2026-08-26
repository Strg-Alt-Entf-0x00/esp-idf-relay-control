#ifndef FREERTOS_FREERTOS_H
#define FREERTOS_FREERTOS_H
#include <stdint.h>
typedef int BaseType_t;
typedef unsigned TickType_t;
#define pdTRUE 1
#define pdFALSE 0
#define pdPASS 1
#define portMAX_DELAY 0xffffffffu
#define pdMS_TO_TICKS(ms) (ms)
#endif
