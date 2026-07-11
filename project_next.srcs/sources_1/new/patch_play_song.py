#!/usr/bin/env python3
"""在 play_song.c 的每段歌词前插入 LYRIC = N; 语句"""
import re

c_path = r"D:\chlor\Desktop\project_next\test_interrupt\play_song.c"

with open(c_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到所有歌词标记的行号
lyric_pattern = re.compile(r'//从现在开始，歌词[：:]\u201c')
intro_pattern = re.compile(r'//从现在开始是[：:]')

# 建立歌词索引映射
# 从注释中提取歌词内容，按出现顺序编号
lyric_map = []  # (line_index, lyric_index)
idx = 1  # 0=前奏, 1=第一句歌词...

for i, line in enumerate(lines):
    if intro_pattern.search(line):
        lyric_map.append((i, 0))  # 前奏 = index 0
    elif lyric_pattern.search(line):
        lyric_map.append((i, idx))
        idx += 1

print(f"Found {len(lyric_map)} lyric markers")
for line_no, lrc_idx in lyric_map:
    print(f"  Line {line_no+1}: lyric_idx={lrc_idx} | {lines[line_no].rstrip()}")

# 在每个歌词标记行之前插入 LYRIC = N;
# 需要从后往前插入，避免行号偏移
output = lines[:]
insert_count = 0

for line_no, lrc_idx in reversed(lyric_map):
    indent = "        "  # 8空格缩进
    insert_line = f"{indent}LYRIC = {lrc_idx};\n"
    output.insert(line_no, insert_line)
    insert_count += 1

# 在文件开头添加 LYRIC 宏定义
# 找到 #define LED 那行，在后面添加
for i, line in enumerate(output):
    if '#define LED' in line:
        output.insert(i+1, '#define LYRIC (*(volatile unsigned int *)0xC0000000)\n')
        break

# 写回文件
with open(c_path, 'w', encoding='utf-8') as f:
    f.writelines(output)

print(f"\nInserted {insert_count} LYRIC writes + 1 #define")
print(f"Modified: {c_path}")
