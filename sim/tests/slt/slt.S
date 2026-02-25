###############################################################################
# File         : slt.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'slt' instruction (set on less than,
#   signed register-register comparison).
#   $s0 = 0x80020000 (large negative number); $t1 = -1 (0xffffffff).
#   $s0 < $t1 (signed), so $v0 = 1 (pass).
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
    lui     $t1, 0xffff         # $t1 = 0xffffffff = -1
    ori     $t1, $t1, 0xffff
    slt     $v0, $s0, $t1       # $s0 (-2147352576) < $t1 (-1)? Yes -> $v0 = 1
    nop
    nop
    sw      $v0, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
