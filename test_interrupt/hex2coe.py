#!/usr/bin/env python3
"""
将 objcopy -O verilog --reverse-bytes=4 生成的 hex 文件转换为 Vivado COE 格式

输入: 空格分隔的字节行（大端序，MSB first）
输出: 每行一个 32 位字，逗号分隔
"""

import sys
import re

def hex2coe(input_file, output_file, depth=16384):
    rom = [0] * depth
    current_addr = 0

    with open(input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            addr_match = re.match(r'@([0-9a-fA-F]+)', line)
            if addr_match:
                current_addr = int(addr_match.group(1), 16) // 4
                continue

            bytes_list = line.split()
            if bytes_list and all(re.match(r'^[0-9a-fA-F]{2}$', b) for b in bytes_list):
                for i in range(0, len(bytes_list) - 3, 4):
                    if current_addr < depth:
                        # 大端序：MSB 在前
                        b0 = int(bytes_list[i], 16)
                        b1 = int(bytes_list[i+1], 16)
                        b2 = int(bytes_list[i+2], 16)
                        b3 = int(bytes_list[i+3], 16)
                        word = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
                        rom[current_addr] = word
                        current_addr += 1

    with open(output_file, 'w', newline='\n') as f:
        f.write('memory_initialization_radix=16;\n')
        f.write('memory_initialization_vector=\n')
        for i, val in enumerate(rom):
            if i < depth - 1:
                f.write(f'{val:08X},\n')
            else:
                f.write(f'{val:08X};\n')

    non_zero = sum(1 for v in rom if v != 0)
    print(f'生成 {output_file}: {depth} words, {non_zero} non-zero entries')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'用法: {sys.argv[0]} <input.hex> <output.coe>')
        sys.exit(1)
    hex2coe(sys.argv[1], sys.argv[2])
