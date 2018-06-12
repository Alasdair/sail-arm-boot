.global _start

.text

_start:
	b	reset

#include "system.h"

/*
 * Switch from EL3 to EL2 for ARMv8 (64-bit)
 * @ep:     kernel entry point
 * @tmp:    temporary register
 *
 * For loading 64-bit OS, x0 is physical address to the FDT blob.
 * They will be passed to the guest.
 */
.macro armv8_switch_to_el2_m, ep, tmp
	msr	cptr_el3, xzr		/* Disable coprocessor traps to EL3 */
	mov	\tmp, #CPTR_EL2_RES1
	msr	cptr_el2, \tmp		/* Disable coprocessor traps to EL2 */

	/* Initialize Generic Timers */
	msr	cntvoff_el2, xzr

	/* Initialize SCTLR_EL2
	 *
	 * setting RES1 bits (29,28,23,22,18,16,11,5,4) to 1
	 * and RES0 bits (31,30,27,26,24,21,20,17,15-13,10-6) +
	 * EE,WXN,I,SA,C,A,M to 0
	 */
	ldr	\tmp, =(SCTLR_EL2_RES1 | SCTLR_EL2_EE_LE |\
			SCTLR_EL2_WXN_DIS | SCTLR_EL2_ICACHE_DIS |\
			SCTLR_EL2_SA_DIS | SCTLR_EL2_DCACHE_DIS |\
			SCTLR_EL2_ALIGN_DIS | SCTLR_EL2_MMU_DIS)
	msr	sctlr_el2, \tmp

	mov	\tmp, sp
	msr	sp_el2, \tmp		/* Migrate SP */
	mrs	\tmp, vbar_el3
	msr	vbar_el2, \tmp		/* Migrate VBAR */

	/*
	 * The next lower exception level is AArch64, 64bit EL2 | HCE |
	 * RES1 (Bits[5:4]) | Non-secure EL0/EL1.
	 * and the SMD depends on requirements.
	 */
	ldr	\tmp, =(SCR_EL3_RW_AARCH64 | SCR_EL3_HCE_EN |\
			SCR_EL3_SMD_DIS | SCR_EL3_RES1 |\
			SCR_EL3_NS_EN)
	msr	scr_el3, \tmp

	/* Return to the EL2_SP2 mode from EL3 */
	ldr	\tmp, =(SPSR_EL_DEBUG_MASK | SPSR_EL_SERR_MASK |\
			SPSR_EL_IRQ_MASK | SPSR_EL_FIQ_MASK |\
			SPSR_EL_M_AARCH64 | SPSR_EL_M_EL2H)
	msr	spsr_el3, \tmp
	msr	elr_el3, \ep
	eret
.endm

reset:
	ldr	x0, =COUNTER_FREQUENCY
	msr	cntfrq_el0, x0

	/* Call main function in bootloader.c */
	ldr	w0, =0xdeadbeef
	bic	sp, x0, #0xf
	stp 	x29, x30, [sp, #-16]!
	bl	main
	ldp 	x29, x30, [sp]

	/* 0x84000000 is the FDT blob */
	ldr	x0, =0x81000000
	/* 0x82080000 is Kernel entry point */
	ldr	x4, =0x82080000
	armv8_switch_to_el2_m 	x4, x5
