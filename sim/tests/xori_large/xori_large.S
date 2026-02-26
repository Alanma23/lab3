###############################################################################
# File         : xori_large.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'xori' instruction with a high-bit immediate.
#   xori zero-extends, so xori $t1, $0, 0x8000 = 0x00008000 not 0xffff8000.
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
    xori    $t1, $0, 0x8000     # A = 0x00008000 (zero-extended)
    ori     $t2, $0, 0x8001     # B = xor(0x00008000, 1) = 0x00008001
    xor     $t3, $t1, $t2       # C = xor(A,B) = 1 if zero-extended correctly
    sw      $t3, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
