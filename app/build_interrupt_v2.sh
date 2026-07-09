#!/bin/bash
# RISC-V 中断测试程序 编译 → COE 文件生成脚本
# 用法: bash build_interrupt_v2.sh
#
# 前提: 已安装 riscv64-linux-musl-gcc 交叉编译器

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CC=riscv64-linux-musl-gcc
OBJDUMP=riscv64-linux-musl-objdump
OBJCOPY=riscv64-linux-musl-objcopy

NAME="interrupt_test_v2"
SRC_C="interrupt_test_v2.c"
SRC_S="intr_vector.S"
LD="rv32i_interrupt_v2.ld"

CFLAGS="-march=rv32i -mabi=ilp32 -O1 -nostartfiles -nostdlib -static -fno-pic -fno-pie -mno-relax"

echo "=== Step 1: 编译汇编文件 ==="
$CC $CFLAGS -c "$SRC_S" -o "${NAME}_vec.o"
echo "  OK: ${NAME}_vec.o"

echo "=== Step 2: 编译 C 文件 ==="
$CC $CFLAGS -c "$SRC_C" -o "${NAME}_c.o"
echo "  OK: ${NAME}_c.o"

echo "=== Step 3: 链接 ==="
$CC $CFLAGS -T "$LD" "${NAME}_vec.o" "${NAME}_c.o" -o "${NAME}.elf"
echo "  OK: ${NAME}.elf"

echo "=== Step 4: 反汇编 ==="
$OBJDUMP -d "${NAME}.elf" > "${NAME}.dis"
echo "  OK: ${NAME}.dis"

echo "=== Step 5: 提取机器码 ==="
grep -E '^\s*[0-9a-f]+:\s+[0-9a-f]+' "${NAME}.dis" | \
    awk '{print $2}' | \
    tr '[:upper:]' '[:lower:]' > "${NAME}.dat"
echo "  OK: ${NAME}.dat ($(wc -l < "${NAME}.dat") 条指令)"

echo "=== Step 6: 生成 COE 文件 ==="
{
    echo "memory_initialization_radix=16;"
    echo -n "memory_initialization_vector="
    paste -sd',' "${NAME}.dat" | sed 's/$/;/'
} > "${NAME}.coe"
echo "  OK: ${NAME}.coe"

echo ""
echo "=== 完成 ==="
echo "生成文件:"
echo "  ${NAME}.elf  - ELF 文件"
echo "  ${NAME}.dis  - 反汇编"
echo "  ${NAME}.coe  - COE 文件 (用于 Vivado ROM_D 初始化)"
echo ""
echo "验证中断向量表地址:"
$OBJDUMP -t "${NAME}.elf" | grep -E "ivt|start|handler"
