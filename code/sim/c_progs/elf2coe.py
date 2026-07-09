#!/usr/bin/env python3
"""Convert RISC-V ELF to .coe file for Vivado ROM IP.
Uses objcopy binary output + padding to 1024 words.
"""
import struct, sys, os, subprocess

def elf_to_coe(elf_path, coe_path, rom_words=1024):
    # Step 1: objcopy to binary
    bin_path = elf_path.replace('.elf', '.bin')
    subprocess.run(['riscv32-unknown-elf-objcopy', '-O', 'binary', elf_path, bin_path],
                   check=True)

    # Step 2: read binary
    with open(bin_path, 'rb') as f:
        data = f.read()

    # Step 3: pad to ROM size and convert to words
    words = []
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        if len(chunk) < 4:
            chunk = chunk + b'\x00' * (4 - len(chunk))
        words.append(struct.unpack('<I', chunk)[0])  # little-endian

    # Pad to ROM size with NOP (addi x0, x0, 0 = 0x00000013)
    while len(words) < rom_words:
        words.append(0x00000013)

    # Step 4: write .coe
    with open(coe_path, 'w') as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        for i, w in enumerate(words):
            comma = "," if i < len(words) - 1 else ";"
            f.write(f"{w:08X}{comma}\n")

    print(f"Generated {coe_path}: {len(words)} words ({rom_words} total, {rom_words*4/1024:.0f}KB)")
    print(f"  Program size: {len(data)} bytes, {len(data)//4} instructions")
    os.remove(bin_path)

if __name__ == '__main__':
    elf = sys.argv[1] if len(sys.argv) > 1 else 'test.elf'
    coe = sys.argv[2] if len(sys.argv) > 2 else 'test.coe'
    elf_to_coe(elf, coe)
