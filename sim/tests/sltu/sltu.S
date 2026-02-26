###############################################################################
# File         : sltu.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'sltu' instruction.
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
    nop
    lui     $t1, 0xffff         # $t1 = 0xffffffff (unsigned maximum)
    ori     $t1, $t1, 0xffff
    sltu    $t0, $s0, $t1       # 0x80020000 < 0xffffffff (unsigned)? Yes -> $t0 = 1
    nop
    nop
    sw      $t0, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
