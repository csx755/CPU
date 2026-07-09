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
    .text : { 
        *(.text.start) 
        *(.text)
        *(.text.interrupt_handlers)
    } :text
    .data : { *(.data*) }
    .bss  : { *(.bss*)  *(COMMON) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) *(.riscv.attributes) }
    
    # 中断向量表放在地址 0x100
    . = 0x100;
    .interrupt_vector : { *(.text.interrupt_vector) }
}