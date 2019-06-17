/*
 * Copyright (C) 2018 Alibaba Group Holding Limited
 */

/*
 * This file supplied RTC one-shot start/stop services for CPU tickless
 * module, verifyied on STM32L496-DISCOVERY with C3/C4 mode.
 * C3: stop mode.
 * C4: standby mode.
 */
#include <k_api.h>

#if (AOS_COMP_PWRMGMT > 0)
#include <stdint.h>
#include <stdbool.h>

#include <cpu_tickless.h>

static pwr_status_t rtc_init(void);
static uint32_t     rtc_one_shot_max_msec(void);
static pwr_status_t rtc_one_shot_start(uint64_t planUs);
static pwr_status_t rtc_one_shot_stop(uint64_t *pPassedUs);

one_shot_timer_t rtc_one_shot = {
    rtc_init,
    rtc_one_shot_max_msec,
    rtc_one_shot_start,
    rtc_one_shot_stop,
};

static uint32_t timer_counter_start = 0;

static pwr_status_t rtc_init(void)
{
    return PWR_OK;
}

static pwr_status_t rtc_one_shot_start(uint64_t planUs)
{
    return PWR_OK;
}

static pwr_status_t rtc_one_shot_stop(uint64_t *pPassedUs)
{
    return PWR_OK;
}

static uint32_t rtc_one_shot_max_msec(void)
{
    return 1000;
}

#endif /* AOS_COMP_PWRMGMT */
