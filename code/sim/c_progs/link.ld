/* Linker script for bare-metal RV32I on our SoC
 * ROM  @ 0x00000000 (4KB, 1024 x 32-bit words)
 * RAM  @ 0x00000000 (shared with ROM address space, Harvard arch)
 * Stack grows downward from top of RAM (0x00001000 = 4KB)
 */

ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x1000   /* 4KB instruction memory */
    RAM (rw)  : ORIGIN = 0x00000000, LENGTH = 0x1000   /* 4KB data memory */
}

SECTIONS
{
    /* Code section in ROM */
    .text : {
        *(.text.init)      /* startup code first */
        *(.text.handler)   /* interrupt handler */
        *(.text)           /* main program */
        *(.text.*)
    } > ROM

    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        *(.srodata.*)
    } > ROM

    /* Initialized data (copied from ROM to RAM by startup) */
    .data : {
        _data_start = .;
        *(.data)
        *(.data.*)
        *(.sdata.*)
        _data_end = .;
    } > RAM AT > ROM
    _data_load = LOADADDR(.data);

    /* BSS (zero-initialized data) */
    .bss : {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss.*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    /* Stack (grows downward from _stack_top) */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    _stack_bottom = _stack_top - 0x400;  /* 1KB stack */

    /* Sanity check: ROM size must not exceed 4KB */
    ASSERT(SIZEOF(.text) + SIZEOF(.rodata) + SIZEOF(.data) <= 0x1000,
           "ERROR: Program exceeds 4KB ROM size!")
}
