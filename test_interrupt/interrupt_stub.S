# 最简中断入口 - 0x200
# 只保存 ra，够用就行
.section .interrupt, "ax"
.global _interrupt_entry
_interrupt_entry:
    addi sp, sp, -16
    sw   ra, 0(sp)
    call interrupt_handler
    lw   ra, 0(sp)
    addi sp, sp, 16
    mret
