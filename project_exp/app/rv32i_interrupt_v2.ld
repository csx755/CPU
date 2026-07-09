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

    .text.start : {
        *(.text.start)
    } :text

    . = 0x100;
    .text.ivt : {
        *(.text.ivt)
    } :text

    .text.handlers : {
        *(.text.handlers)
    } :text

    .text : {
        *(.text)
    } :text

    .data : { *(.data*) }
    .bss  : { *(.bss*)  *(COMMON) }

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}
