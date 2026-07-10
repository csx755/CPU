MEMORY {
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 4096
}

ENTRY(_start)

SECTIONS {
    .text 0x00000000 : {
        _start = .;
        *(.text.startup)
        *(.text*)
        *(.rodata*)
        *(.data*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
    } > ROM

    .interrupt 0x00000200 : {
        *(.interrupt)
    } > ROM
}
