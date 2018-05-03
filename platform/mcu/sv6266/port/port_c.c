/*
 * Copyright (C) 2015-2017 Alibaba Group Holding Limited
 */

#include <k_api.h>
#include "mcu_def.h"
#include "soc_defs.h"
#include "sys/intc.h"
#include "sys/systick.h"

extern uint32_t _SDA_BASE_ __attribute__ ((weak));
void *cpu_task_stack_init(cpu_stack_t *stack_base, size_t stack_size,
                          void *arg, task_entry_t entry)
{
	int i;
    cpu_stack_t *pxTopOfStack;
    cpu_stack_t	*pxOriginalTOS;
    cpu_stack_t *old_stk;
    uint32_t temp = (uint32_t)(stack_base + stack_size);

    temp &= 0xfffffff8;

    pxTopOfStack = (cpu_stack_t *)temp;
    pxOriginalTOS = pxTopOfStack;
    
        *--pxTopOfStack = (uint32_t)0x01010101L * 1;				/* R1 */
        *--pxTopOfStack = (uint32_t)arg;											/* R0 : argument */
        *--pxTopOfStack = (uint32_t)__builtin_return_address(0);	/* $30:LP */
        *--pxTopOfStack = (uint32_t)&_SDA_BASE_;                   	/* $29:GP For relax support */
        *--pxTopOfStack = (uint32_t)pxOriginalTOS;					/* $28:FP */
		i = 27;
        for (; i >= 2; i--)
        {
			*--pxTopOfStack = (uint32_t)0x01010101UL * i;
		}

#ifdef __NDS32_EXT_IFC__
#ifndef CONFIG_NO_NDS32_EXT_IFC
		*--pxTopOfStack = (uint32_t)0x01010101UL * 40;				/* $IFC_LP */
#endif
#endif

		/* IPSW, enable GIE, clear IFCON */
        *--pxTopOfStack = (uint32_t)((GET_PSW() | (1UL << PSW_offGIE)) & (~(1UL << PSW_offIFCON)));
		/* IPC */
        *--pxTopOfStack = (uint32_t)entry;
		/* PSW */
        *--pxTopOfStack = (uint32_t)(GET_PSW() | (1UL << PSW_offINTL) );
        
        old_stk = pxTopOfStack;                                	  	/* Save curent unaligned sp */
        *--pxTopOfStack = (uint32_t)((uint32_t)old_stk);    	/* sp(R31) */
        if ((uint32_t)pxTopOfStack & 0x7)
        {
			*--pxTopOfStack = (uint32_t)((uint32_t)old_stk);    /* sp(R31) */
		}

    return pxTopOfStack;
}

size_t cpu_intrpt_save(void)
{
	size_t psw = __nds32__mfsr(NDS32_SR_PSW);
	__nds32__gie_dis();
	return psw;
}

void cpu_intrpt_restore(size_t psw)
{
	__nds32__mtsr(psw, NDS32_SR_PSW);
}

static uint32_t psw_saved[32];
static uint32_t cs_index = 0;
void vPortEnterCritical(void)
{
	if(32 == cs_index) return;

	psw_saved[cs_index] = __nds32__mfsr(NDS32_SR_PSW);
	__nds32__gie_dis();
	cs_index++;
}

void vPortExitCritical(void)
{
	if(0 == cs_index) return;
	
	cs_index--;
	__nds32__mtsr(psw_saved[cs_index], NDS32_SR_PSW);
}

void   cpu_intrpt_switch(void)
{
       /* trigger swi*/
       __nds32__mtsr(0x10000,NDS32_SR_INT_PEND);
       __nds32__isb();
}

void   cpu_task_switch(void)
{
       /* trigger swi*/
       __nds32__mtsr(0x10000,NDS32_SR_INT_PEND);
       __nds32__isb();
}

extern void systick_isr();
void   cpu_first_task_start(void)
{
	/* enable SWI for context switch */
	intc_irq_set_priority(IRQ_SWI, LOWEST);
	intc_irq_enable(IRQ_SWI);
	
	/* enable systick */
	intc_register_isr(IRQ_UTIMER_0, systick_isr);
	intc_irq_set_priority(IRQ_UTIMER_0, LOWEST);
	intc_irq_enable(IRQ_UTIMER_0);
	
	/* start  timer */
	systick_set_period((1000*1000)/RHINO_CONFIG_TICKS_PER_SECOND);
	systick_start();
	
	/* start first task */
	__asm__ __volatile__
	(
		"b\t CtxRestore"
		:
		:
		:
	);
}
