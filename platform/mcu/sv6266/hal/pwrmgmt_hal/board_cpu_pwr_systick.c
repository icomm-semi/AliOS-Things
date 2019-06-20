/*
 * Copyright (C) 2018 Alibaba Group Holding Limited
 */

/*
DESCRIPTION
This file provides two fundtions systick_suspend()/systick_resume()
which is used by cpu tickless module to suspend/resume system tick
interrupt.

Differrent board may has different way to suspend/resume system tick
interrupt, please reference your board/soc user manual to find the
detail for how to implement these two functions.
*/

#include <k_api.h>
#include <drv_tmr.h>
#include <soc_defs.h>

#if (AOS_COMP_PWRMGMT > 0)

void systick_suspend(void)
{
    intc_irq_disable(IRQ_SYSTICK);
    hal_tm_deinit(TM_TU0_US);
}

void systick_resume(void)
{
    hal_tm_init(TM_TU0_US);
    intc_irq_enable(IRQ_SYSTICK);
}

#endif /* AOS_COMP_PWRMGMT */
