###############################################################################
# SIMD Sobel: 4 pixels per iteration using PADD.B, PSUB.B, PSLL.B, PABS.B,
# PUNPKLO, PUNPKHI. sobel(inbuf, outbuf, rows, cols); stride in=642, out=640.
# R-type .word: (rs<<21)|(rt<<16)|(rd<<11)|(shamt<<6)|funct
#   PADD_B 0x30, PSUB_B 0x31, PSLL_B 0x32, PABS_B 0x33, PUNPKLO 0x34, PUNPKHI 0x35
###############################################################################

	.text
	.set	noreorder
	.set	nomacro
	.globl	sobel
	.ent	sobel
sobel:
	beq	$a2, $0, $sobel_exit
	nop

	addiu	$sp, $sp, -40
	sw	$ra, 36($sp)
	sw	$s6, 32($sp)
	sw	$s5, 28($sp)
	sw	$s4, 24($sp)
	sw	$s3, 20($sp)
	sw	$s2, 16($sp)
	sw	$s1, 12($sp)
	sw	$s0, 8($sp)

	move	$s6, $a2
	move	$s4, $a3
	li	$s5, 0

$sobel_row_loop:
	sltu	$t9, $s5, $s6
	beq	$t9, $0, $sobel_done
	nop

	li	$t8, 642
	mul	$s1, $s5, $t8
	addu	$s1, $a0, $s1
	addiu	$t8, $s5, 1
	li	$t7, 642
	mul	$s2, $t8, $t7
	addu	$s2, $a0, $s2
	addiu	$t8, $s5, 2
	mul	$s3, $t8, $t7
	addu	$s3, $a0, $s3
	li	$t7, 640
	mul	$s0, $s5, $t7
	addu	$s0, $a1, $s0

	subu	$t5, $s4, 4
	li	$t4, 0

$sobel_simd_loop:
	sltu	$t9, $t4, $t5
	beq	$t9, $0, $sobel_tail
	nop

	# Load prev: words at j and j+2 -> prev_l, prev_m, prev_r
	addu	$t8, $s1, $t4
	lw	$t0, 0($t8)
	lw	$t1, 2($t8)
	srl	$t2, $t0, 8
	sll	$t3, $t1, 24
	or	$t2, $t2, $t3
	srl	$t3, $t0, 16
	sll	$t8, $t1, 16
	or	$t3, $t3, $t8
	# $t0=prev_l, $t2=prev_m, $t3=prev_r

	addu	$t8, $s2, $t4
	lw	$t6, 0($t8)
	lw	$t7, 2($t8)
	srl	$t8, $t6, 8
	sll	$t9, $t7, 24
	or	$t8, $t8, $t9
	srl	$t9, $t6, 16
	sll	$v0, $t7, 16
	or	$t9, $t9, $v0
	# $t6=curr_l, $t8=curr_m, $t9=curr_r

	addu	$v0, $s3, $t4
	lw	$v1, 0($v0)
	lw	$v0, 2($v0)
	srl	$t7, $v1, 8
	sll	$t1, $v0, 24
	or	$t7, $t7, $t1
	srl	$t1, $v1, 16
	sll	$v0, $v0, 16
	or	$t1, $t1, $v0
	# $v1=next_l, $t7=next_m, $t1=next_r

	# Gx = (prev_r - prev_l) + 2*(curr_r - curr_l) + (next_r - next_l). Result in $v0.
	.word	0x01681031
	nop
	nop
	# PSUB_B $v0, $t3, $t0  (prev_r - prev_l)
	.word	0x032e0831
	nop
	nop
	# PSUB_B $at, $t9, $t6  (curr_r - curr_l)
	.word	0x00210872
	nop
	nop
	# PSLL.B $at, $at, 1
	.word	0x00410830
	nop
	nop
	# PADD_B $v0, $v0, $at
	.word	0x01208831
	nop
	nop
	# PSUB_B $at, $t1, $v1  (next_r - next_l)
	.word	0x00410830
	nop
	nop
	# PADD_B $v0, $v0, $at
	.word	0x00401033
	nop
	nop
	# PABS_B $v0, $v0

	# Gy = (next_l - prev_l) + 2*(next_m - prev_m) + (next_r - prev_r). Result in $v1.
	.word	0x00608831
	nop
	nop
	# PSUB_B $at, $v1, $t0  (next_l - prev_l)
	.word	0x01ea7031
	nop
	nop
	# PSUB_B $t6, $t7, $t2  (next_m - prev_m)
	.word	0x01c87072
	nop
	nop
	# PSLL.B $t6, $t6, 1
	.word	0x002e0830
	nop
	nop
	# PADD_B $at, $at, $t6
	.word	0x012b7031
	nop
	nop
	# PSUB_B $t6, $t1, $t3  (next_r - prev_r)
	.word	0x002e0830
	nop
	nop
	# PADD_B $at, $at, $t6
	.word	0x00201833
	nop
	nop
	# PABS_B $v1, $at

	# Combine: save |Gx| |Gy|, unpack, add halfwords, clamp, pack, store.
	move	$t8, $v0
	move	$t9, $v1
	.word	0x03004034
	nop
	nop
	# PUNPKLO $t0, $t8
	.word	0x03004835
	nop
	nop
	# PUNPKHI $t1, $t8
	.word	0x03305034
	nop
	nop
	# PUNPKLO $t2, $t9
	.word	0x03305835
	nop
	nop
	# PUNPKHI $t3, $t9
	addu	$t0, $t0, $t2
	addu	$t1, $t1, $t3
	# Clamp to 255: if t0[15:0]>255 then 255, same for t0[31:16], t1[15:0], t1[31:16]. Pack into one word and store.
	andi	$t2, $t0, 0xffff
	srl	$t3, $t0, 16
	andi	$t3, $t3, 0xffff
	addiu	$t7, $0, 255
	sltu	$t6, $t7, $t2
	movn	$t2, $t7, $t6
	sltu	$t6, $t7, $t3
	movn	$t3, $t7, $t6
	andi	$t2, $t2, 0xff
	andi	$t3, $t3, 0xff
	sll	$t3, $t3, 8
	or	$t2, $t2, $t3
	andi	$t0, $t1, 0xffff
	srl	$t1, $t1, 16
	andi	$t1, $t1, 0xffff
	sltu	$t6, $t7, $t0
	movn	$t0, $t7, $t6
	sltu	$t6, $t7, $t1
	movn	$t1, $t7, $t6
	andi	$t0, $t0, 0xff
	andi	$t1, $t1, 0xff
	sll	$t1, $t1, 8
	or	$t0, $t0, $t1
	sll	$t0, $t0, 16
	or	$t2, $t2, $t0
	addu	$at, $s0, $t4
	sw	$t2, 0($at)

	addiu	$t4, $t4, 4
	j	$sobel_simd_loop
	nop

$sobel_tail:
	sltu	$t9, $t4, $s4
	beq	$t9, $0, $sobel_next_row
	nop
	# One scalar pixel: prev_l,prev_m,prev_r=t0,t1,t2; curr_l,curr_m,curr_r=t3,t6,t7; next_l,next_m,next_r=v0,v1,t8
	addu	$t8, $s1, $t4
	lbu	$t0, 0($t8)
	lbu	$t1, 1($t8)
	lbu	$t2, 2($t8)
	addu	$t8, $s2, $t4
	lbu	$t3, 0($t8)
	lbu	$t6, 1($t8)
	lbu	$t7, 2($t8)
	addu	$t8, $s3, $t4
	lbu	$v0, 0($t8)
	lbu	$v1, 1($t8)
	lbu	$t8, 2($t8)
	# Gx = (prev_r-prev_l) + 2*(curr_r-curr_l) + (next_r-next_l) in $t9
	subu	$t9, $t2, $t0
	subu	$at, $t7, $t3
	sll	$at, $at, 1
	addu	$t9, $t9, $at
	subu	$at, $t8, $v0
	addu	$t9, $t9, $at
	# Gy = (next_l-prev_l) + 2*(next_m-prev_m) + (next_r-prev_r) in $t5
	subu	$t5, $v0, $t0
	subu	$at, $v1, $t1
	sll	$at, $at, 1
	addu	$t5, $t5, $at
	subu	$at, $t8, $t2
	addu	$t5, $t5, $at
	# |Gx| in t9, |Gy| in t5
	slt	$at, $t9, $0
	subu	$t6, $0, $t9
	movn	$t9, $t6, $at
	slt	$at, $t5, $0
	subu	$t6, $0, $t5
	movn	$t5, $t6, $at
	addu	$t9, $t9, $t5
	addiu	$t5, $0, 255
	sltu	$at, $t5, $t9
	movn	$t9, $t5, $at
	addu	$t5, $s0, $t4
	sb	$t9, 0($t5)
	addiu	$t4, $t4, 1
	j	$sobel_tail
	nop

$sobel_next_row:
	addiu	$s5, $s5, 1
	j	$sobel_row_loop
	nop

$sobel_done:
	lw	$s0, 8($sp)
	lw	$s1, 12($sp)
	lw	$s2, 16($sp)
	lw	$s3, 20($sp)
	lw	$s4, 24($sp)
	lw	$s5, 28($sp)
	lw	$s6, 32($sp)
	lw	$ra, 36($sp)
	addiu	$sp, $sp, 40
$sobel_exit:
	jr	$ra
	nop
	.end	sobel
