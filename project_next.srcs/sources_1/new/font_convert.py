#!/usr/bin/env python3
"""Convert font_ascii_8_8.coe to font.mem for Verilog $readmemh"""
import re, sys

coe_path = r"D:\chlor\Desktop\VGA接口\font_ascii_8_8.coe"
mem_path = r"D:\chlor\Desktop\project_next\project_next.srcs\sources_1\new\font.mem"

with open(coe_path, 'r') as f:
    text = f.read()

# Extract all binary values
vals = re.findall(r'[01]{8}', text)
print(f"Extracted {len(vals)} font bytes")

# Convert binary to hex (2 digits, uppercase)
with open(mem_path, 'w') as f:
    for i, v in enumerate(vals):
        hex_val = f"{int(v, 2):02X}"
        f.write(hex_val)
        if i < len(vals) - 1:
            f.write('\n')

print(f"Written {len(vals)} entries to {mem_path}")
