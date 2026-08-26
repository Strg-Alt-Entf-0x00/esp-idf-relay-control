#ifndef FREERTOS_TASK_H
#define FREERTOS_TASK_H
#include "freertos/FreeRTOS.h"
typedef void *TaskHandle_t;
typedef void (*TaskFunction_t)(void *);
BaseType_t xTaskCreate(TaskFunction_t task, const char *name, unsigned stack_size, void *arg, unsigned priority, TaskHandle_t *handle);
void vTaskDelete(TaskHandle_t task);
void vTaskDelay(TickType_t ticks);
TaskHandle_t xTaskGetCurrentTaskHandle(void);
#endif
