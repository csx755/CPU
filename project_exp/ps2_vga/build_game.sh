#!/bin/bash
# 打地鼠游戏 编译脚本
# 用法: bash build_game.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CC=riscv64-linux-musl-gcc
OBJDUMP=riscv64-linux-musl-objdump

NAME="whack_a_mole"
SRC_C="whack_a_mole.c"
LD="../app/rv32i.ld"

CFLAGS="-march=rv32i -mabi=ilp32 -O1 -nostartfiles -nostdlib -static -fno-pic -fno-pie -mno-relax"
LDFLAGS="-no-pie -nostartfiles -nostdlib"

echo "=== Step 1: 编译 C 文件 ==="
$CC $CFLAGS -c "$SRC_C" -o "${NAME}_c.o"
echo "  OK: ${NAME}_c.o"

echo "=== Step 2: 链接 ==="
$CC $LDFLAGS -march=rv32i -mabi=ilp32 -T "$LD" "${NAME}_c.o" -lgcc -o "${NAME}.elf"
echo "  OK: ${NAME}.elf"

echo "=== Step 3: 反汇编 ==="
$OBJDUMP -d "${NAME}.elf" > "${NAME}.dis"
echo "  OK: ${NAME}.dis"

echo "=== Step 4: 提取机器码 ==="
grep -E '^\s*[0-9a-f]+:\s+[0-9a-f]+' "${NAME}.dis" | \
    awk '{print $2}' | \
    tr '[:upper:]' '[:lower:]' > "${NAME}.dat"
echo "  OK: ${NAME}.dat ($(wc -l < "${NAME}.dat") 条指令)"

echo "=== Step 5: 生成 COE 文件 ==="
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
echo "将 ${NAME}.coe 复制到 Vivado ROM_D 初始化文件即可"
