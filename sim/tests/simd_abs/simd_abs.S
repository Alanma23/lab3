###############################################################################
# Test packed SIMD (PADD.B, PSUB.B, PSLL.B, PABS.B, PUNPKLO, PUNPKHI) and ABS.
# Custom instructions are emitted via .word (SPECIAL funct codes).
# R-type: [31:26]=op(0), [25:21]=rs, [20:16]=rt, [15:11]=rd, [10:6]=shamt, [5:0]=funct
###############################################################################

    .section .boot, "x"
    .balign 4
    .set    noreorder
    .global boot
    .ent    boot
boot:
    lui     $s0, 0x8002
    ori     $s1, $0, 1

    # PADD.B: 0x01020304 + 0x00010203 = 0x01030507 (per-byte, truncate to 8b)
    lui     $t0, 0x0102
    ori     $t0, $t0, 0x0304
    lui     $t1, 0x0001
    ori     $t1, $t1, 0x0203
    .word   0x01095030          # PADD.B $t2, $t0, $t1  (funct 0x30)
    nop
    nop
    nop
    lui     $t3, 0x0103
    ori     $t3, $t3, 0x0507
    subu    $t4, $t2, $t3       # expect 0
    nop
    nop
    bne     $t4, $0, $fail1
    nop

    # PSUB.B: 0x05050505 - 0x01010101 = 0x04040404
    lui     $t0, 0x0505
    ori     $t0, $t0, 0x0505
    ori     $t1, $0, 0x0101
    sll     $t1, $t1, 16
    ori     $t1, $t1, 0x0101
    .word   0x01095031          # PSUB.B $t2, $t0, $t1  (funct 0x31)
    nop
    nop
    nop
    lui     $t3, 0x0404
    ori     $t3, $t3, 0x0404
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail2
    nop

    # PSLL.B: 0x01020408 << 1 per byte = 0x02040810 (shamt=1)
    lui     $t0, 0x0102
    ori     $t0, $t0, 0x0408
    .word   0x01005072          # PSLL.B $t2, $t0, 1   (rs=8, rd=10, shamt=1, funct 0x32)
    nop
    nop
    nop
    lui     $t3, 0x0204
    ori     $t3, $t3, 0x0810
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail3
    nop

    # PABS.B: 0x80808080 (all -128) -> 0x80808080
    lui     $t0, 0x8080
    ori     $t0, $t0, 0x8080
    .word   0x01005033          # PABS.B $t2, $t0  (rs=8, rd=10, funct 0x33)
    nop
    nop
    nop
    lui     $t3, 0x8080
    ori     $t3, $t3, 0x8080
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail4
    nop

    # PUNPKLO: 0x12345678 -> lower 2 bytes zero-extend: 0x00560078
    lui     $t0, 0x1234
    ori     $t0, $t0, 0x5678
    .word   0x01005034          # PUNPKLO $t2, $t0  (rs=8, rd=10, funct 0x34)
    nop
    nop
    nop
    lui     $t3, 0x0056
    ori     $t3, $t3, 0x0078
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail5
    nop

    # PUNPKHI: 0x12345678 -> upper 2 bytes: 0x00120034
    lui     $t0, 0x1234
    ori     $t0, $t0, 0x5678
    .word   0x01005035          # PUNPKHI $t2, $t0  (rs=8, rd=10, funct 0x35)
    nop
    nop
    nop
    lui     $t3, 0x0012
    ori     $t3, $t3, 0x0034
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail6
    nop

    # ABS: -1 -> 1
    addiu   $t0, $0, -1
    .word   0x01005038          # ABS $t2, $t0  (rs=8, rd=10, funct 0x38)
    nop
    nop
    nop
    ori     $t3, $0, 1
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail
    nop

    # ABS: -42 -> 42
    addiu   $t0, $0, -42
    .word   0x01005038          # ABS $t2, $t0
    nop
    nop
    nop
    ori     $t3, $0, 42
    subu    $t4, $t2, $t3
    nop
    nop
    bne     $t4, $0, $fail
    nop

$pass:
    sw      $s1, 4($s0)
    sw      $s1, 0($s0)
$done:
    j       $done
    nop

$fail:
    sw      $0, 4($s0)
    sw      $s1, 0($s0)
    j       $done
    nop

    .end boot
