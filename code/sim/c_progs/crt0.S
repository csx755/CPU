# Startup code: bare-metal RV32I entry point
# Sets up stack, clears BSS, calls main()
# Also provides the interrupt handler (mtvec target)

.section .text.init
.globl _start
_start:
    # Initialize stack pointer
    la sp, _stack_top

    # Clear BSS section
    la t0, _bss_start
    la t1, _bss_end
1:  bge t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:

    # Jump to main (use jal to avoid AUIPC dependency)
    jal ra, main

    # main() should never return — if it does, infinite loop
    j _start

# ============================================================
# Interrupt handler (placed at a fixed offset via section attr)
# mtvec should be set to this address
# ============================================================
.section .text.handler, "ax"
.globl trap_handler
.globl _trap_vector
.align 6   # 64-byte aligned (RV32I mtvec requirement for direct mode)

_trap_vector:
trap_handler:
    # Save caller-saved registers
    addi sp, sp, -64
    sw ra,  0(sp)
    sw t0,  4(sp)
    sw t1,  8(sp)
    sw t2,  12(sp)
    sw t3,  16(sp)
    sw t4,  20(sp)
    sw t5,  24(sp)
    sw t6,  28(sp)
    sw a0,  32(sp)
    sw a1,  36(sp)
    sw a2,  40(sp)
    sw a3,  44(sp)
    sw a4,  48(sp)
    sw a5,  52(sp)
    sw a6,  56(sp)
    sw a7,  60(sp)

    # Read mcause to determine interrupt type
    csrrw t0, mcause, zero       # t0 = mcause

    # Check if external interrupt (bit 31 = 1) or exception
    srli t1, t0, 31             # t1 = mcause[31]
    beqz t1, is_exception       # bit31=0 → exception (ECALL)

    # ===== External interrupt (timer / peripheral) =====
is_interrupt:
    # Check if timer interrupt (mcause == 0x8000000B)
    # 0x8000000B = machine external interrupt
    # Already known to be an interrupt — service it
    jal ra, c_interrupt_handler

    # Clear timer interrupt: reload Counter_x
    # Counter at 0xF0000008
    li t0, 0xF0000008
    li t1, 80                  # reload value = ~100us
    sw t1, 0(t0)

    j trap_return

    # ===== Exception (ECALL) =====
is_exception:
    # Read mepc (return address for ECALL is ECALL itself)
    # ECALL increments mepc by 4 in software
    csrrw t0, mepc, zero       # t0 = mepc (PC of ECALL)
    addi t0, t0, 4             # mepc += 4 (skip ECALL)
    csrrw zero, mepc, t0       # mepc = t0

    # Call C handler for ECALL
    jal ra, c_ecall_handler

    j trap_return

    # ===== Return from trap =====
trap_return:
    # Restore caller-saved registers
    lw ra,  0(sp)
    lw t0,  4(sp)
    lw t1,  8(sp)
    lw t2,  12(sp)
    lw t3,  16(sp)
    lw t4,  20(sp)
    lw t5,  24(sp)
    lw t6,  28(sp)
    lw a0,  32(sp)
    lw a1,  36(sp)
    lw a2,  40(sp)
    lw a3,  44(sp)
    lw a4,  48(sp)
    lw a5,  52(sp)
    lw a6,  56(sp)
    lw a7,  60(sp)
    addi sp, sp, 64

    mret                         # PC ← mepc, MIE ← 1
