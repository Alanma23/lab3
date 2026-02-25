###############################################################################
# File         : jal.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'jal' instruction.
#   JAL should jump to $func and set $ra = PC+8 (address after delay slot).
#   jr $ra then returns to $return, which falls through to $finish.
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
    jal     $func               # Jump to $func; $ra = address of $return
    nop                         # Delay slot

$return:                        # $ra should point here
    j       $finish
    nop                         # Delay slot (safe)

$finish:
    sw      $v0, 4($s0)         # Set the test result (1=pass)
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

$func:
    ori     $v0, $0, 1          # Set result to pass
    jr      $ra                 # Return to $return
    nop                         # Delay slot

    .end boot
