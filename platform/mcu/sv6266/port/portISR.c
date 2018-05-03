#include <k_api.h>
#include "mcu_def.h"
#include "soc_defs.h"
#include "sys/systick.h"
#include "sys/intc.h"

void systick_isr()
{
	systick_stop();
	intc_irq_clean(IRQ_UTIMER_0);
	
	systick_set_period((1000*1000)/RHINO_CONFIG_TICKS_PER_SECOND);
	systick_start();
    krhino_intrpt_enter();
    krhino_tick_proc();
    krhino_intrpt_exit();
}
