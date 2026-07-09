#!/bin/bash
# RISC-V 交叉编译 → COE 文件生成脚本
# 用法: bash build.sh led_btn.c

set -e

SRC=$1
if [ -z "$SRC" ]; then
    echo "用法: bash build.sh <源文件.c>"
    exit 1
fi

NAME="${SRC%.c}"
CC=riscv64-linux-musl-gcc
OBJDUMP=riscv64-linux-musl-objdump

echo "=== Step 1: 编译 ==="
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
$CC -march=rv32i -mabi=ilp32 -O1 -nostartfiles -nostdlib \
    -e start -T "$SCRIPT_DIR/rv32i.ld" \
    "$SRC" -o "$NAME.elf"
echo "  ✓ 编译完成: $NAME.elf"

echo "=== Step 2: 反汇编 ==="
$OBJDUMP -d "$NAME.elf" > "$NAME.dis"
echo "  ✓ 反汇编完成: $NAME.dis"

echo "=== Step 3: 提取机器码 ==="
# 提取每行的机器码（去掉地址和汇编助记符）
grep -E '^\s*[0-9a-f]+:\s+[0-9a-f]+' "$NAME.dis" | \
    awk '{print $2}' | \
    tr '[:upper:]' '[:lower:]' > "$NAME.dat"
echo "  ✓ 机器码提取完成: $NAME.dat ($(wc -l < "$NAME.dat") 条指令)"

echo "=== Step 4: 生成 COE 文件 ==="
# 生成 Xilinx COE 格式
{
    echo "memory_initialization_radix=16;"
    echo -n "memory_initialization_vector="
    # 每行一个机器码，逗号分隔，最后一个分号结尾
    paste -sd',' "$NAME.dat" | sed 's/$/;/'
} > "$NAME.coe"
echo "  ✓ COE 文件生成: $NAME.coe"

echo ""
echo "=== 完成 ==="
echo "将 $NAME.coe 复制到 Vivado 项目中替换 ROM_D 的初始化文件即可"
