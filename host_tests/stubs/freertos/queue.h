#ifndef FREERTOS_QUEUE_H
#define FREERTOS_QUEUE_H
#include "freertos/FreeRTOS.h"
typedef void *QueueHandle_t;
QueueHandle_t xQueueCreate(unsigned length, unsigned item_size);
BaseType_t xQueueSend(QueueHandle_t queue, const void *item, TickType_t wait);
BaseType_t xQueueReceive(QueueHandle_t queue, void *item, TickType_t wait);
void vQueueDelete(QueueHandle_t queue);
#endif
