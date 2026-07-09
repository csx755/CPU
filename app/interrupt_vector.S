.section .text.start
.globl _start
_start:
    # 设置栈指针
    li sp, 1024
    # 跳转到main函数
    call main

.section .text.interrupt_vector
.globl interrupt_vector
interrupt_vector:
    # 中断向量表
    # 每个中断源占4字节（一条指令）
    # 基地址 0x100，偏移 = 中断编号 * 4
    
    # 中断源0: 定时器中断 (最高优先级)
    j timer_interrupt_handler
    
    # 中断源1: 外部中断源0
    j external_interrupt_handler_0
    
    # 中断源2: 外部中断源1
    j external_interrupt_handler_1
    
    # 中断源3: 外部中断源2
    j external_interrupt_handler_2
    
    # 中断源4: 外部中断源3
    j external_interrupt_handler_3
    
    # 中断源5: 外部中断源4
    j external_interrupt_handler_4
    
    # 中断源6: 外部中断源5 (最低优先级)
    j external_interrupt_handler_5

.section .text.interrupt_handlers
.globl timer_interrupt_handler
timer_interrupt_handler:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 读取SCAUSE寄存器
    csrr t0, 0x103  # SCAUSE
    
    # 处理定时器中断
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret

.globl external_interrupt_handler_0
external_interrupt_handler_0:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 处理外部中断源0
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret

.globl external_interrupt_handler_1
external_interrupt_handler_1:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 处理外部中断源1
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret

.globl external_interrupt_handler_2
external_interrupt_handler_2:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 处理外部中断源2
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret

.globl external_interrupt_handler_3
external_interrupt_handler_3:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 处理外部中断源3
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret

.globl external_interrupt_handler_4
external_interrupt_handler_4:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 处理外部中断源4
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret

.globl external_interrupt_handler_5
external_interrupt_handler_5:
    # 保存寄存器
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    
    # 处理外部中断源5
    # 这里可以添加具体的中断处理逻辑
    
    # 恢复寄存器
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    
    # 返回
    eret