OUTPUT_ARCH(riscv)
OUTPUT_FORMAT(elf32-littleriscv)
ENTRY(start)

PHDRS
{
    text PT_LOAD FLAGS(5);
}

SECTIONS
{
    . = 0x0;
    .text : { *(.text.start) *(.text*) } :text
    .data : { *(.data*) }
    .bss  : { *(.bss*)  *(COMMON) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) *(.riscv.attributes) }
}
