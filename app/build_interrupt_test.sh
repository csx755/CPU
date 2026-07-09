#!/bin/bash

# 编译选项
RISCV_GCC=riscv32-unknown-elf-gcc
RISCV_OBJCOPY=riscv32-unknown-elf-objcopy
RISCV_OBJDUMP=riscv32-unknown-elf-objdump

# 编译选项
CFLAGS="-march=rv32i -mabi=ilp32 -O0 -g"
LDFLAGS="-T rv32i_interrupt.ld -nostartfiles"

# 编译中断向量表
echo "编译中断向量表..."
$RISCV_GCC $CFLAGS -c interrupt_vector.S -o interrupt_vector.o

# 编译测试程序
echo "编译测试程序..."
$RISCV_GCC $CFLAGS -c interrupt_test.c -o interrupt_test.o

# 链接
echo "链接..."
$RISCV_GCC $LDFLAGS interrupt_vector.o interrupt_test.o -o interrupt_test.elf

# 生成二进制文件
echo "生成二进制文件..."
$RISCV_OBJCOPY -O binary interrupt_test.elf interrupt_test.bin

# 生成反汇编
echo "生成反汇编..."
$RISCV_OBJDUMP -d interrupt_test.elf > interrupt_test.dis

# 生成COE文件（用于Vivado初始化ROM）
echo "生成COE文件..."
python3 -c "
import sys
with open('interrupt_test.bin', 'rb') as f:
    data = f.read()
# 填充到4字节对齐
while len(data) % 4 != 0:
    data += b'\x00'
# 生成COE文件
with open('interrupt_test.coe', 'w') as f:
    f.write('memory_initialization_radix=16;\n')
    f.write('memory_initialization_vector=\n')
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], 'little')
        if i < len(data) - 4:
            f.write(f'{word:08x},\n')
        else:
            f.write(f'{word:08x};\n')
"

echo "构建完成！"
echo "生成的文件："
echo "  interrupt_test.elf - ELF文件"
echo "  interrupt_test.bin - 二进制文件"
echo "  interrupt_test.dis - 反汇编文件"
echo "  interrupt_test.coe - COE文件（用于Vivado）"