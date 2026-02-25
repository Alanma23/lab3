###############################################################################
# File         : movz.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'movz' instruction (move if zero).
#   movz $t2, $t0, $0  : $t2 gets $t0 because condition ($0==0) is zero -> move
#   movz $t1, $t0, $s1 : $t1 stays 0 because condition ($s1==1) is nonzero -> no move
#   Pass if $t2 == $t0 (0xdeafbeef) AND $t1 == 0.
#
###############################################################################

    .section .boot, "x"
    .balign 4
    .set    noreorder
    .global boot
    .ent    boot
boot:
    lui     $s0, 0x8002         # Load the base address of the status/test registers
    ori     $s1, $0, 1          # Prepare the 'done' status
    lui     $t0, 0xdeaf
    nop
    ori     $t0, $t0, 0xbeef
    ori     $t1, $0, 0          # $t1 = 0 initially
    movz    $t2, $t0, $0        # $t2 gets 0xdeafbeef ($0 == 0 -> move)
    movz    $t1, $t0, $s1       # $t1 remains 0 ($s1 = 1 != 0 -> no move)
    subu    $t3, $t2, $t0       # $t3 = 0 if movz wrote correctly
    nop
    sltiu   $v0, $t3, 1         # $v0 = 1 if $t3 == 0
    sltiu   $v1, $t1, 1         # $v1 = 1 if $t1 == 0 (suppressed move worked)
    and     $v0, $v0, $v1
    nop
    sw      $v0, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
