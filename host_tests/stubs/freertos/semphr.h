#ifndef FREERTOS_SEMPHR_H
#define FREERTOS_SEMPHR_H
#include "freertos/FreeRTOS.h"
typedef void *SemaphoreHandle_t;
typedef struct { int value; } StaticSemaphore_t;
SemaphoreHandle_t xSemaphoreCreateMutexStatic(StaticSemaphore_t *storage);
SemaphoreHandle_t xSemaphoreCreateBinary(void);
BaseType_t xSemaphoreTake(SemaphoreHandle_t semaphore, TickType_t wait);
BaseType_t xSemaphoreGive(SemaphoreHandle_t semaphore);
void vSemaphoreDelete(SemaphoreHandle_t semaphore);
#endif
