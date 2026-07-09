.section .text.start
.globl _start
_start:
    li sp, 4096
    call main

# ============================================================
# 中断向量表 — 固定在 0x100 (由 linker script 控制)
# CPU: EXC_Vector = 0x100 + INT_PEND * 4
#   [0] 定时器中断 (int_sources[0] = counter0_OUT)
#   [1] 按键中断   (int_sources[1] = |BTN_out)
#   [2~6] 未使用
#   [7] ECALL      (软件异常, SCAUSE=8)
# ============================================================
.section .text.ivt
.globl ivt
ivt:
    j handler_timer        # [0] 定时器中断
    j handler_btn          # [1] 按键中断
    j handler_nop          # [2]
    j handler_nop          # [3]
    j handler_nop          # [4]
    j handler_nop          # [5]
    j handler_nop          # [6]
    j handler_ecall        # [7] ECALL

# ============================================================
# 通用现场保存 / 恢复宏
# ============================================================
.macro SAVE_CONTEXT
    addi sp, sp, -64
    sw   ra,  0(sp)
    sw   t0,  4(sp)
    sw   t1,  8(sp)
    sw   t2, 12(sp)
    sw   t3, 16(sp)
    sw   a0, 20(sp)
    sw   a1, 24(sp)
    sw   a2, 28(sp)
    sw   a3, 32(sp)
.endm

.macro RESTORE_CONTEXT
    lw   ra,  0(sp)
    lw   t0,  4(sp)
    lw   t1,  8(sp)
    lw   t2, 12(sp)
    lw   t3, 16(sp)
    lw   a0, 20(sp)
    lw   a1, 24(sp)
    lw   a2, 28(sp)
    lw   a3, 32(sp)
    addi sp, sp, 64
.endm

# ============================================================
# 定时器中断 handler
#   counter0_OUT 为电平信号, 只要定时器在跑就会持续为高
#   handler 读取/翻转全局 flag, 让主循环可见
# ============================================================
.section .text.handlers
.globl handler_timer
handler_timer:
    SAVE_CONTEXT

    # timer_flag ^= 1
    la   t0, g_timer_flag
    lw   t1, 0(t0)
    xori t1, t1, 1
    sw   t1, 0(t0)

    # timer_count++
    la   t0, g_timer_count
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)

    RESTORE_CONTEXT
    .word 0x00200073        # eret

# ============================================================
# 按键中断 handler
#   int_sources[1] = |BTN_out, 电平触发
#   读取按键状态, 做边沿检测后更新全局变量
# ============================================================
.globl handler_btn
handler_btn:
    SAVE_CONTEXT

    # 读取 {BTN, SW}
    li   t0, 0xE0000000
    lw   t1, 0(t0)
    srli t1, t1, 16          # btn[4:0]
    andi t1, t1, 0x1F

    # 边沿检测: pressed = btn & ~last_btn
    la   t0, g_last_btn
    lw   t2, 0(t0)
    xor  t3, t1, t2          # changed
    and  t3, t3, t1          # pressed (rising edge)
    sw   t1, 0(t0)           # 更新 last_btn

    # CENTER (bit4): counter++
    andi t0, t3, 0x10
    beqz t0, btn_not_center
    la   t0, g_counter
    lw   t1, 0(t0)
    addi t1, t1, 1
    andi t1, t1, 0xFF
    sw   t1, 0(t0)
btn_not_center:

    # UP (bit0): counter--
    andi t0, t3, 0x01
    beqz t0, btn_not_up
    la   t0, g_counter
    lw   t1, 0(t0)
    addi t1, t1, -1
    andi t1, t1, 0xFF
    sw   t1, 0(t0)
btn_not_up:

    # DOWN (bit2): counter = 0
    andi t0, t3, 0x04
    beqz t0, btn_not_down
    la   t0, g_counter
    li   t1, 0
    sw   t1, 0(t0)
btn_not_down:

    # LEFT (bit3): led_mode ^= 1
    andi t0, t3, 0x08
    beqz t0, btn_not_left
    la   t0, g_led_mode
    lw   t1, 0(t0)
    xori t1, t1, 1
    sw   t1, 0(t0)
btn_not_left:

    # btn_count++ (用于调试)
    la   t0, g_btn_count
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)

    RESTORE_CONTEXT
    .word 0x00200073        # eret

# ============================================================
# ECALL handler
#   SEPC 已由硬件保存为 ECALL 指令的 PC
#   硬件已做: SEPC = ret_addr + 4 (跳过 ecall)
#   所以只需更新计数器, 直接 eret
# ============================================================
.globl handler_ecall
handler_ecall:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   t0, g_ecall_count
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)

    lw   ra, 0(sp)
    addi sp, sp, 4
    .word 0x00200073        # eret

# ============================================================
# 默认 handler (不做事, 直接返回)
# ============================================================
.globl handler_nop
handler_nop:
    .word 0x00200073        # eret
