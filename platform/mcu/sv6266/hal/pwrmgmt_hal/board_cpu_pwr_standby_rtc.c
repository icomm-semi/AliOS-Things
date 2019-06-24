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
#include <hal_tm.h>

#define RTC_HW_TIMER_ID        TM_TU1_US
#define RTC_HW_TIMER_MAX_COUNT 65535
#define RTC_HW_TIMER_FREQ      1000000

static pwr_status_t rtc_init(void);
static uint32_t     rtc_one_shot_max_msec(void);
static pwr_status_t rtc_one_shot_start(uint64_t planUs);
static pwr_status_t rtc_one_shot_stop(uint64_t *pPassedUs);

one_shot_timer_t standby_rtc_one_shot = {
    rtc_init,
    rtc_one_shot_max_msec,
    rtc_one_shot_start,
    rtc_one_shot_stop,
};

static void tmr_irq_handler (uint32_t irq_num)
{
//    printf ("%s:%d: In function: '%s': tmr%ld interrupt occurred\n", __FILENAME__, __LINE__ - 1, __func__, irq_num - IRQ_UTIMER_0);
    drv_tmr_clear_interrupt_status (irq_num - IRQ_UTIMER_0);
    printf ("\n");
}

static pwr_status_t rtc_init(void)
{
    drv_tmr_init(RTC_HW_TIMER_ID);
    drv_tmr_sw_rst(RTC_HW_TIMER_ID);
    drv_tmr_register_irq_handler(RTC_HW_TIMER_ID, tmr_irq_handler);
    return PWR_OK;
}

static pwr_status_t rtc_one_shot_start(uint64_t planUs)
{
    int32_t count = 0;

    if (drv_tmr_get_interrupt_status(RTC_HW_TIMER_ID)) {
        drv_tmr_clear_interrupt_status(RTC_HW_TIMER_ID);
    }

    count = planUs * RTC_HW_TIMER_FREQ / (uint64_t)1000000;

    drv_tmr_enable(RTC_HW_TIMER_ID, TM_MODE_AUTO_RELOAD, count);
    return PWR_OK;
}

static pwr_status_t rtc_one_shot_stop(uint64_t *pPassedUs)
{
    int32_t count = 0;

    count = drv_tmr_get_current_count(RTC_HW_TIMER_ID);

    if ((count != 0) && (drv_tmr_get_interrupt_status(RTC_HW_TIMER_ID))) {
        count = RTC_HW_TIMER_MAX_COUNT - count + RTC_HW_TIMER_MAX_COUNT;
    } else {
        count = RTC_HW_TIMER_MAX_COUNT - count;
    }
    *pPassedUs = count * (uint64_t)1000000 / RTC_HW_TIMER_FREQ;

    drv_tmr_disable(RTC_HW_TIMER_ID);

  //  printf("[%s]!sleep_ed %lld\n", __func__, *pPassedUs);
    return PWR_OK;
}

static uint32_t rtc_one_shot_max_msec(void)
{
    return RTC_HW_TIMER_MAX_COUNT * 1000 / RTC_HW_TIMER_FREQ;
}

#endif /* AOS_COMP_PWRMGMT */
