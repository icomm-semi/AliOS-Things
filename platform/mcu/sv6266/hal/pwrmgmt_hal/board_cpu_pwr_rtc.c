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
#include <osal.h>

#define MSEC_PER_SYSTICK ((uint64_t)1000000 / RHINO_CONFIG_TICKS_PER_SECOND)

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
extern uint32_t g_power_xtal_force_active;
extern uint32_t g_power_user_force_active;
extern uint32_t g_power_rtc_force_active;

extern uint32_t systick_remain_us;
extern uint32_t systick_passed_us;

#if defined(SUPPORT_LOW_POWER) && (SUPPORT_LOW_POWER == 1)
void bsp_rtc_startup (void *pdata) {
    sys_rtc_cali();
    OS_TaskDelete(NULL);
}
#endif

static pwr_status_t rtc_init(void)
{
    //printf("[%s]!!!!!!!!!!!\n", __func__);
#if defined(SUPPORT_LOW_POWER) && (SUPPORT_LOW_POWER == 1)
    sys_lowpower_init();
    OS_TaskCreate(bsp_rtc_startup, "rtc", 512, NULL, OS_TASK_HIGH_PRIO, NULL);
#endif
    return PWR_OK;
}

extern uint32_t g_sleep_us;

#define M_RTC_MIN_SLEEP_US_TIME         (1594+50)

static pwr_status_t rtc_one_shot_start(uint64_t planUs)
{
    if (planUs < M_RTC_MIN_SLEEP_US_TIME) {
        //printf("[%s]failed !!%lld\n", __func__, planUs);
        return PWR_ERR;
    }
    if (g_power_user_force_active) {
        //printf("[%s] user_force_active\n", __func__);
        return PWR_ERR;
    }
    if (g_power_rtc_force_active) {
        //printf("[%s] rtc_force_active\n", __func__);
        return PWR_ERR;
    }
    if (g_power_xtal_force_active) {
        //printf("x");
        //printf("[%s] xtal_force_active\n", __func__);
        return PWR_ERR;
    }
    //printf("[%s]!!%lld\n", __func__, planUs);
    g_sleep_us = planUs;
    return PWR_OK;
}

static pwr_status_t rtc_one_shot_stop(uint64_t *pPassedUs)
{
    uint64_t passed_timer = 0;

    passed_timer      = g_sleep_us + systick_passed_us;
    *pPassedUs        = passed_timer / MSEC_PER_SYSTICK * MSEC_PER_SYSTICK;
    systick_remain_us = passed_timer % MSEC_PER_SYSTICK;
    //printf("[%s]!sleep_ed %lld\n", __func__, *pPassedUs);
    return PWR_OK;
}

static uint32_t rtc_one_shot_max_msec(void)
{
//    printf("[%s]\n", __func__);
    return 327;
}

#endif /* AOS_COMP_PWRMGMT */
