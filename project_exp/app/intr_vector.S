.section .text.start
.globl _start
_start:
    li sp, 4096
    call main

# ============================================================
# 中断向量表 — 固定在 0x100 (由 linker script 控制)
# 每个入口一条 JAL，跳转到对应 handler
# ECALL 的 INT_PEND=7, 所以需要 8 个入口 (0~7)
# ============================================================
.section .text.ivt
.globl ivt
ivt:
    j handler_timer        # [0] 定时器中断  (最高优先级)
    j handler_btn          # [1] 按键中断
    j handler_default      # [2]
    j handler_default      # [3]
    j handler_default      # [4]
    j handler_default      # [5]
    j handler_default      # [6] (最低优先级)
    j handler_ecall        # [7] ECALL 指令 (INT_PEND=7)

# ============================================================
# 通用现场保存 / 恢复宏
# ============================================================
.macro SAVE_CONTEXT
    addi sp, sp, -64
    sw   ra,  0(sp)
    sw   t0,  4(sp)
    sw   t1,  8(sp)
    sw   t2, 12(sp)
    sw   a0, 16(sp)
    sw   a1, 20(sp)
    sw   a2, 24(sp)
    sw   a3, 28(sp)
    csrr t0, 0x102          # SEPC
    sw   t0, 32(sp)
    csrr t0, 0x103          # SCAUSE
    sw   t0, 36(sp)
.endm

.macro RESTORE_CONTEXT
    lw   t0, 32(sp)
    csrw 0x102, t0          # 恢复 SEPC
    lw   ra,  0(sp)
    lw   t0,  4(sp)
    lw   t1,  8(sp)
    lw   t2, 12(sp)
    lw   a0, 16(sp)
    lw   a1, 20(sp)
    lw   a2, 24(sp)
    lw   a3, 28(sp)
    addi sp, sp, 64
.endm

# ============================================================
# 定时器中断 handler
# ============================================================
.section .text.handlers
.globl handler_timer
handler_timer:
    SAVE_CONTEXT

    # 读取 SCAUSE 判断中断类型
    csrr t0, 0x103
    li   t1, 0
    bne  t0, t1, timer_not_timer   # SCAUSE != 0 → 不是定时器

    # --- 定时器中断处理 ---
    # 翻转 flag (全局变量)
    la   t0, g_timer_flag
    lw   t1, 0(t0)
    xori t1, t1, 1
    sw   t1, 0(t0)

    # LED 闪烁: 读当前 LED 值, 翻转 bit2
    li   t0, 0xF0000000
    lw   t1, 0(t0)           # 读当前 LED
    xori t1, t1, 0x04        # 翻转 bit2
    sw   t1, 0(t0)           # 写回 LED

timer_not_timer:
    RESTORE_CONTEXT
    .word 0x00200073        # eret

# ============================================================
# 按键中断 handler
# ============================================================
.globl handler_btn
handler_btn:
    SAVE_CONTEXT

    csrr t0, 0x103
    li   t1, 1
    bne  t0, t1, btn_done

    # --- 按键中断处理 ---
    # 读取按键 (E0000000)
    li   t0, 0xE0000000
    lw   t1, 0(t0)
    srli t1, t1, 16          # 取 btn[4:0]
    andi t1, t1, 0x1F

    # 保存按键状态到全局变量
    la   t0, g_btn_press
    sw   t1, 0(t0)

    # LED 显示按键值 (左移2位对齐)
    slli t2, t1, 2
    li   t0, 0xF0000000
    sw   t2, 0(t0)

    # 按键计数器 +1
    la   t0, g_btn_count
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)

btn_done:
    RESTORE_CONTEXT
    .word 0x00200073        # eret

# ============================================================
# 默认 handler (不做事)
# ============================================================
.globl handler_default
handler_default:
    addi sp, sp, -4
    sw   ra, 0(sp)
    csrr t0, 0x103          # 读 SCAUSE (丢弃)
    lw   ra, 0(sp)
    addi sp, sp, 4
    .word 0x00200073        # eret

# ============================================================
# ECALL handler
#   ECALL 是同步异常, 保存的 SEPC 指向 ECALL 指令本身
#   需要将 SEPC+4, 使 eret 跳过 ECALL 执行下一条指令
# ============================================================
.globl handler_ecall
handler_ecall:
    addi sp, sp, -8
    sw   ra, 0(sp)
    sw   t0, 4(sp)

    csrr t0, 0x102          # 读 SEPC
    addi t0, t0, 4          # SEPC += 4 (跳过 ecall)
    csrw 0x102, t0          # 写回 SEPC

    # 更新全局计数器
    la   t0, g_ecall_count
    lw   ra, 0(t0)
    addi ra, ra, 1
    sw   ra, 0(t0)

    lw   t0, 4(sp)
    lw   ra, 0(sp)
    addi sp, sp, 8
    .word 0x00200073        # eret
