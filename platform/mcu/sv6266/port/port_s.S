!********************************************************************************************************
!                                               FreeRTOS
!
!                               (c) Copyright 2010, Andes Techonology
!                                          All Rights Reserved
!
!                                           NDS32 Generic Port
!                                            GNU C Compiler
!
! File    : os_cpu_a.S
! Version : V1.0
! By      : greentime @ Andes Technology
!
!********************************************************************************************************
!********************************************************************************************************
! INCLUDE ASSEMBLY CONSTANTS
!********************************************************************************************************

#include "mcu_def.h"
//#include "FreeRTOSConfig.h"
#include "os_cpu_common.h"

!********************************************************************************************************
! IMPORT and EXPORT
!********************************************************************************************************
    .section .fast_boot_code
	.global OS_Trap_Interrupt_SWI
	.global CtxSave
	.global CtxRestore
#if 1
	.global OS_Trap_Int_Comm
#endif
	.global OS_Trap_Syscall
#if defined(CONFIG_OSC_SUPPORT)
	.global OS_Trap_General_Exception
#endif
	.global __OS_Int_Stack
	.global gOsFromISR
	
	.macro TCBSaveMacro
		bal krhino_stack_ovf_check
		! Store the new top of stack for the task.
		la	$r3, g_active_task
		lwi	$r4, [$r3]
		swi	$sp, [$r4]
	.endm



	! Restore to new task's context
	.macro TCBRestoreMacro
		! use new pxCurrentTCB to get new stack pointer
		la	$r0, g_active_task
		la	$r1, g_preferred_ready_task
		lwi	$r2, [$r1]
		swi	$r2, [$r0]
		lwi $sp, [$r2]
	.endm

	.macro FrameSaveMacro
		la	$r3, OriginalFp
		swi	$fp, [$r3]
		la	$r3, OriginalSp
		swi	$sp, [$r3]
	.endm

	.macro FrameRestoreMacro
		la	$r0, OriginalFp
		lwi	$fp, [$r0]
		la	$r0, OriginalSp
		lwi	$sp, [$r0]
	.endm

!*************************************************************************
!
!	PortMacro Function, Call by C function
!	Used by First start Scheduler
!	Warm up a Initalized Task
!
!*************************************************************************
!CtxSave:
!
!		mfsr	$r0, $PSW
!		mtsr	$r0, $IPSW
!		mtsr	$lp, $IPC
!		pushm $r0, $r1
!		SAVE_ALL
!		TCBSaveMacro
!		ret

	! Restore to new task's context
CtxRestore:
		TCBRestoreMacro
		RESTORE_ALL
		popm $r0, $r1
		iret



!********************************************************************************************************
!                   PERFORM A CONTEXT SWITCH - OSCtxSw()
!
! Note(s) : 1) OSIntCtxSw() is called with IRQ DISABLED
!
!           2) The pseudo-code for OSCtxSw() is:
!              a) $IPSW <- $PSW, $IPC <- $lp
!              b) CtxSaveMacro		: Save current task's context
!	       c) TCBSaveMacro		: Save current task's sp into TCB
!              d) vTaskSwitchContext	: get the highest priority of Task
!              e) IntlSwitch		: Switch to interruption level 1
!	       f) TCBRestoreMacro	: Restore to the highest priority task's sp from TCB
!              g) CtxRestoreMacro	: Restore to the highest priority task's context 
!
!********************************************************************************************************
    .type OS_Trap_Interrupt_SWI, @function
    .align 2
OS_Trap_Interrupt_SWI:
	movi    $r0, 0x0
	mtsr    $r0, $INT_PEND                  ! clean SWI pending

	IntlSwitch #0                   	! Switch to interrupt level 0

	SAVE_ALL
	TCBSaveMacro				! Save current task's sp into TCB

	!CallFn	vTaskSwitchContext		! get the highest priority of Task

	TCBRestoreMacro				! Restore to original task's TCB
	RESTORE_ALL
	popm $r0, $r1
	iret
    .size OS_Trap_Interrupt_SWI, .-OS_Trap_Interrupt_SWI

!********************************************************************************************************
! IRQ Interrupt Service Routine
!********************************************************************************************************

#if 1
    .type OS_Trap_Int_Comm, @function
    .align 2
OS_Trap_Int_Comm:
	CALLER_SAVE
	IntlSwitch #0                   ! Switch to interrupt level 0

	! Handle nesting counter
	la	$r0, gOsFromISR				! if (gOsFromISR == 0) {
	lbi	$r1, [$r0]
	bnez	$r1, 2f

	FrameSaveMacro
	la	$fp, __OS_Int_Stack
	la	$sp, __OS_Int_Stack			! }

2:
	addi    $r1, $r1, 1				! gOsFromISR++
	swi	$r1, [$r0]

Arg_r0:	
	mfsr $r0, $ITYPE
	andi $r0, $r0, 0x0FE0
	srli $r0, $r0, 5
	addi $r0, $r0, #-9
	!li $r1, IRQ_SYSTICK

Call_ISR: 
	la	$lp, OS_CPU_Vector_Table	! $lp = &OS_CPU_Vector_Table[]
	lw	$r2, [$lp+($r0<<2)]			! $r2 = OS_CPU_Vector[int_no]
	!beq $r0, $r1, GIE_DIS
	!setgie.e
	!dsb
GIE_DIS:
	jral $r2						! call ISR
	!setgie.d
	!dsb

        							! Check for non-nested interruption return
	la      $r0, gOsFromISR			! gOsFromISR--
	lwi	$r1, [$r0]		
	addi    $r1, $r1, -1		
	swi	$r1, [$r0]
	
	bnez    $r1, 3f					! if (gOsFromISR == 0) {
	FrameRestoreMacro				! }
3:

	CALLER_RESTORE
!1:
	popm	$r0, $r1
	iret
    .size OS_Trap_Int_Comm, .-OS_Trap_Int_Comm
#endif

!********************************************************************************************************
! POINTERS TO VARIABLES
!********************************************************************************************************
.section .bss
.global OriginalSp
!	.data
	.align 3
	.skip 4
OriginalSp:

.global OriginalFp
!	.data
	.align 3
	.skip 4
OriginalFp:

.global gOsFromISR
!	.data
	.align 3
	.skip 4
gOsFromISR:

	.end
