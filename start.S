.global _start

.text

_start:
	b	reset_el3
	b	reset_el2

#include "system.h"

.macro armv8_switch_to_el2_m, xreg1
	/* 64bit EL2 | HCE | SMD | RES1 (Bits[5:4]) | Non-secure EL0/EL1 */
	mov	\xreg1, #0x5b1
	msr	scr_el3, \xreg1
	msr	cptr_el3, xzr		/* Disable coprocessor traps to EL3 */
	mov	\xreg1, #0x33ff
	msr	cptr_el2, \xreg1	/* Disable coprocessor traps to EL2 */

	/* Initialize Generic Timers */
	msr	cntvoff_el2, xzr

	/* Initialize SCTLR_EL2
	 *
	 * setting RES1 bits (29,28,23,22,18,16,11,5,4) to 1
	 * and RES0 bits (31,30,27,26,24,21,20,17,15-13,10-6) +
	 * EE,WXN,I,SA,C,A,M to 0
	 */
	mov	\xreg1, #0x0830
	movk	\xreg1, #0x30C5, lsl #16
	msr	sctlr_el2, \xreg1

	/* Return to the EL2_SP2 mode from EL3 */
	mov	\xreg1, sp
	msr	sp_el2, \xreg1		/* Migrate SP */
	mrs	\xreg1, vbar_el3
	msr	vbar_el2, \xreg1	/* Migrate VBAR */
	mov	\xreg1, #0x3c9
	msr	spsr_el3, \xreg1	/* EL2_SP2 | D | A | I | F */
	ldr	\xreg1, =0x80000004
	msr	elr_el3, \xreg1
	eret
.endm

.macro armv8_switch_to_el1_m, xreg1, xreg2
	/* Initialize Generic Timers */
	mrs	\xreg1, cnthctl_el2
	orr	\xreg1, \xreg1, #0x3	/* Enable EL1 access to timers */
	msr	cnthctl_el2, \xreg1
	msr	cntvoff_el2, xzr

	/* Initilize MPID/MPIDR registers */
	mrs	\xreg1, midr_el1
	mrs	\xreg2, mpidr_el1
	msr	vpidr_el2, \xreg1
	msr	vmpidr_el2, \xreg2

	/* Disable coprocessor traps */
	mov	\xreg1, #0x33ff
	msr	cptr_el2, \xreg1	/* Disable coprocessor traps to EL2 */
	msr	hstr_el2, xzr		/* Disable coprocessor traps to EL2 */
	mov	\xreg1, #3 << 20
	msr	cpacr_el1, \xreg1	/* Enable FP/SIMD at EL1 */

	/* Initialize HCR_EL2 */
	mov	\xreg1, #(1 << 31)		/* 64bit EL1 */
	orr	\xreg1, \xreg1, #(1 << 29)	/* Disable HVC */
	msr	hcr_el2, \xreg1

	/* SCTLR_EL1 initialization
	 *
	 * setting RES1 bits (29,28,23,22,20,11) to 1
	 * and RES0 bits (31,30,27,21,17,13,10,6) +
	 * UCI,EE,EOE,WXN,nTWE,nTWI,UCT,DZE,I,UMA,SED,ITD,
	 * CP15BEN,SA0,SA,C,A,M to 0
	 */
	mov	\xreg1, #0x0800
	movk	\xreg1, #0x30d0, lsl #16
	msr	sctlr_el1, \xreg1

	/* Return to the EL1_SP1 mode from EL2 */
	mov	\xreg1, sp
	msr	sp_el1, \xreg1		/* Migrate SP */
	mrs	\xreg1, vbar_el2
	msr	vbar_el1, \xreg1	/* Migrate VBAR */
	mov	\xreg1, #0x3c5
	msr	spsr_el2, \xreg1	/* EL1_SP1 | D | A | I | F */
	ldr	\xreg1, =0x82080000
	msr	elr_el2, \xreg1
	eret
.endm

reset_el3:
	ldr	x0, =COUNTER_FREQUENCY
	msr	cntfrq_el0, x0

	/* Call main function in bootloader.c */
	ldr	w0, =0xdeadbeef
	bic	sp, x0, #0xf
	stp 	x29, x30, [sp, #-16]!
	bl	main
	ldp 	x29, x30, [sp]

	armv8_switch_to_el2_m 	x0

reset_el2:
	/* 0x81000000 is the FDT blob */
	ldr	x0, =0x81000000
	/* x1 -- x3 must be zero'd */
	ldr     x1, =0x0
	ldr	x2, =0x0
	ldr	x3, =0x0
	armv8_switch_to_el1_m 	x4, x5
