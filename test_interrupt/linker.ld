MEMORY {
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 16384
}

ENTRY(_start)

SECTIONS {
    /* 启动跳转指令在 0x000（CPU 复位入口） */
    .boot 0x00000000 : {
        *(.boot)
    } > ROM

    /* 中断向量固定在 0x200（SCPU mtvec） */
    .interrupt 0x00000200 : {
        *(.interrupt)
    } > ROM

    /* 所有代码和数据从 0x300 开始 */
    .text 0x00000300 : {
        *(.text*)
        *(.rodata*)
        *(.data*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
    } > ROM
}
