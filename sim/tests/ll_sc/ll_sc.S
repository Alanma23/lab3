###############################################################################
# File         : ll_sc.S
# Project      : EE180 Lab 3: MIPS
#
# Standards/Formatting:
#   MIPS gas, soft tab, 80 column
#
# Description:
#   Test the functionality of the 'll' (load-linked) and 'sc'
#   (store-conditional) instructions.
#   Test 1: LL followed by SC should succeed ($t2 = 1).
#   Test 2: LL followed by SW (breaking reservation) followed by SC
#           should fail ($t4 = 0).
#   Pass if both conditions hold.
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
    ori     $t0, $0, 0x3210     # Base address for test memory
    nop
    nop
    nop

    # Test 1: LL followed immediately by SC (no intervening store)
    # Expected: SC succeeds, $t2 = 1
    ll      $t1, 0($t0)         # Load-linked: loads mem[$t0], sets atomic bit
    ori     $t2, $0, 1          # Value to store (also the pass value)
    sc      $t2, 0($t0)         # Store-conditional: should succeed, $t2 <- 1
    nop
    nop
    nop
    nop
    nop

    # Test 2: LL followed by SW (breaks reservation), then SC
    # Expected: SC fails, $t4 = 0
    ll      $t3, 4($t0)         # Load-linked: loads mem[$t0+4], sets atomic bit
    nop
    sw      $t3, 4($t0)         # Intervening store: clears atomic bit
    nop
    ori     $t4, $0, 1          # Value to try to store
    sc      $t4, 4($t0)         # Store-conditional: should fail, $t4 <- 0
    nop
    nop
    nop
    nop
    nop

    # Pass if $t2 == 1 (SC1 succeeded) AND $t4 == 0 (SC2 failed)
    sltiu   $v1, $t4, 1         # $v1 = 1 if $t4 == 0
    and     $v0, $t2, $v1       # $v0 = $t2 & ($t4==0); pass = 1 & 1 = 1
    nop
    sw      $v0, 4($s0)         # Set the test result
    sw      $s1, 0($s0)         # Set 'done'

$done:
    j       $done
    nop

    .end boot
