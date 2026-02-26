	.file	1 "sobel_mips.c"
	.section .mdebug.abi32
	.previous
	.nan	legacy
	.gnu_attribute 4, 3
	.text
	.align	2
	# sobel() is provided by sobel_simd.S (SIMD implementation)
	.align	2
	.globl	start_wait
	.set	nomips16
	.set	nomicromips
	.ent	start_wait
	.type	start_wait, @function
start_wait:
	.frame	$sp,0,$31		# vars= 0, regs= 0/0, args= 0, gp= 0
	.mask	0x00000000,0
	.fmask	0x00000000,0
	.set	noreorder
	.set	nomacro
	li	$3,-2147352576			# 0xffffffff80020000
$L23:
	lw	$2,8($3)
	andi	$2,$2,0x1
	beq	$2,$0,$L23
	nop

	lw	$2,8($3)
	srl	$3,$2,2
	srl	$2,$2,12
	andi	$3,$3,0x3ff
	andi	$2,$2,0x3ff
	sw	$3,0($4)
	j	$31
	sw	$2,0($5)

	.set	macro
	.set	reorder
	.end	start_wait
	.size	start_wait, .-start_wait
	.align	2
	.globl	done_wait
	.set	nomips16
	.set	nomicromips
	.ent	done_wait
	.type	done_wait, @function
done_wait:
	.frame	$sp,0,$31		# vars= 0, regs= 0/0, args= 0, gp= 0
	.mask	0x00000000,0
	.fmask	0x00000000,0
	.set	noreorder
	.set	nomacro
	li	$3,1			# 0x1
	li	$2,-2147352576			# 0xffffffff80020000
	sw	$3,0($2)
	li	$3,-2147352576			# 0xffffffff80020000
$L29:
	lw	$2,8($3)
	andi	$2,$2,0x1
	bne	$2,$0,$L29
	li	$2,-2			# 0xfffffffffffffffe

	sw	$2,0($3)
	j	$31
	nop

	.set	macro
	.set	reorder
	.end	done_wait
	.size	done_wait, .-done_wait
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.set	nomips16
	.set	nomicromips
	.ent	main
	.type	main, @function
main:
	.frame	$sp,40,$31		# vars= 0, regs= 5/0, args= 16, gp= 0
	.mask	0x800f0000,-4
	.fmask	0x00000000,0
	.set	noreorder
	.set	nomacro
	addiu	$sp,$sp,-40
	sw	$19,32($sp)
	sw	$18,28($sp)
	sw	$17,24($sp)
	sw	$31,36($sp)
	sw	$16,20($sp)
	li	$19,-2147483648			# 0xffffffff80000000
	li	$18,1			# 0x1
	li	$17,-2			# 0xfffffffffffffffe
$L31:
	li	$16,-2147352576			# 0xffffffff80020000
$L38:
	lw	$2,8($16)
	andi	$2,$2,0x1
	beq	$2,$0,$L31
	nop

	lw	$2,8($16)
	lw	$7,8($16)
	srl	$4,$7,24
	srl	$5,$7,25
	srl	$6,$7,2
	srl	$7,$7,12
	or	$4,$4,$19
	or	$5,$5,$19
	andi	$6,$6,0x3ff
	jal	sobel
	andi	$7,$7,0x3ff

	sw	$18,0($16)
	li	$3,-2147352576			# 0xffffffff80020000
$L39:
	lw	$2,8($3)
	andi	$2,$2,0x1
	bne	$2,$0,$L39
	nop

	sw	$17,0($3)
	j	$L38
	li	$16,-2147352576			# 0xffffffff80020000

	.set	macro
	.set	reorder
	.end	main
	.size	main, .-main
	.ident	"GCC: (GNU) 4.9.1"
