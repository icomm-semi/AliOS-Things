/*
 * Copyright (C) 2015-2017 Alibaba Group Holding Limited
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <aos/yloop.h>
#include <aos/kernel.h>
#include "netmgr.h"
#include "hal/wifi.h"

#define TEST_CONNECT_AP_ONLY 1
#define TEST_BASE_LOWPOWER   0

#define DEMO_TASK_PRI       20
#define DEMO_TASK_STACKSIZE 1025

static aos_task_t demotask1;
static aos_task_t demotask2;

extern uint64_t g_idle_count[];

static void wifi_service_event(input_event_t *event, void *priv_data)
{
    int status = -1;
    if (event->type != EV_WIFI) {
        return;
    }

    if (event->code != CODE_WIFI_ON_GOT_IP) {
        return;
    }

    krhino_task_suspend(krhino_task_find("tcp/ip"));

#if (WIFI_CONFIG_SUPPORT_LOWPOWER > 0)
    wifi_enter_powersave();
#endif
}

void demo_task1(void *arg)
{
    int count1 = 0;

    while (1) {
        printf("count1 = %d, timems = %d, idle = %d\r\n", count1++, (unsigned int)aos_now_ms(), (unsigned int)g_idle_count[0]);
        aos_msleep(1000);
    }
}

void demo_task2(void *arg)
{
    int count2 = 0;

    while (1) {
        /* printf("count2 = %d\n", count2++); */
        aos_msleep(2000);
    }
}

int application_start(int argc, char *argv[])
{
    printf("pwr test started.\r\n");
//    cpu_pwr_minisleep_ms_set(10000);

#if (TEST_BASE_LOWPOWER > 0)
    aos_task_new_ext(&demotask1, "demo1", demo_task1, NULL, DEMO_TASK_STACKSIZE, DEMO_TASK_PRI);
    aos_task_new_ext(&demotask2, "demo2", demo_task2, NULL, DEMO_TASK_STACKSIZE, DEMO_TASK_PRI);
#endif

#if (TEST_CONNECT_AP_ONLY > 0)
    netmgr_init();
    aos_register_event_filter(EV_WIFI, wifi_service_event, NULL);

    netmgr_ap_config_t config;
    strncpy(config.ssid, "h3c_router01", sizeof("h3c_router01"));
    strncpy(config.pwd, "iot123456", sizeof("iot123456"));
    netmgr_set_ap_config(&config);

    netmgr_start(false);
    aos_loop_run();
#endif

    return 0;
}

