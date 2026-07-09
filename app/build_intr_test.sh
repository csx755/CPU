#!/bin/bash
# RISC-V 中断功能测试 编译脚本
# 用法: bash build_intr_test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CC=riscv64-linux-musl-gcc
OBJDUMP=riscv64-linux-musl-objdump

NAME="intr_test"
SRC_C="intr_test.c"
SRC_S="intr_test.S"
LD="rv32i_interrupt_v2.ld"

CFLAGS="-march=rv32i -mabi=ilp32 -O1 -nostartfiles -nostdlib -static -fno-pic -fno-pie -mno-relax"
LDFLAGS="-no-pie -nostartfiles -nostdlib"

echo "=== Step 1: 编译汇编 ==="
$CC $CFLAGS -c "$SRC_S" -o "${NAME}_vec.o"
echo "  OK"

echo "=== Step 2: 编译 C ==="
$CC $CFLAGS -c "$SRC_C" -o "${NAME}_c.o"
echo "  OK"

echo "=== Step 3: 链接 ==="
$CC $LDFLAGS -march=rv32i -mabi=ilp32 -T "$LD" "${NAME}_vec.o" "${NAME}_c.o" -o "${NAME}.elf"
echo "  OK"

echo "=== Step 4: 反汇编 ==="
$OBJDUMP -d "${NAME}.elf" > "${NAME}.dis"
echo "  OK"

echo "=== Step 5: 提取机器码 ==="
grep -E '^\s*[0-9a-f]+:\s+[0-9a-f]+' "${NAME}.dis" | \
    awk '{print $2}' | \
    tr '[:upper:]' '[:lower:]' > "${NAME}.dat"
echo "  OK ($(wc -l < "${NAME}.dat") 条指令)"

echo "=== Step 6: 生成 COE ==="
{
    echo "memory_initialization_radix=16;"
    echo -n "memory_initialization_vector="
    paste -sd',' "${NAME}.dat" | sed 's/$/;/'
} > "${NAME}.coe"
echo "  OK: ${NAME}.coe"

echo ""
echo "=== 完成 ==="
echo "将 ${NAME}.coe 复制到 Vivado ROM_D 初始化文件即可"
echo ""
echo "验证向量表地址:"
$OBJDUMP -t "${NAME}.elf" | grep -E "ivt|start|handler"
