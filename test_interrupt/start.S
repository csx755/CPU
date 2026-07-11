# 启动代码 - 设置栈指针后跳转到 main
.section .boot, "ax"
.global _start
_start:
    # 设置栈指针（用 RAM 顶部）
    lui  sp, 0x00001
    # 跳转到 main
    jal  x0, main
