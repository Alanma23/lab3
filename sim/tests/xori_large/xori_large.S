###############################################################################
# File         : xori_large.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of 'xori' with a large immediate (0x8000).
#   XORI uses zero-extension, so xori $t1, $0, 0x8000 should produce
#   0x00008000 (not sign-extended 0xffff8000).
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
    xori    $t1, $0, 0x8000     # $t1 = 0x0 ^ 0x00008000 = 0x00008000 (zero-extended)
    lui     $t2, 0x0000         # Expected: 0x00008000
    ori     $t2, $t2, 0x8000
    subu    $t3, $t1, $t2       # $t3 = 0 if xori result is correct
    sltiu   $v0, $t3, 1         # $v0 = 1 if $t3 == 0
    sw      $v0, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
