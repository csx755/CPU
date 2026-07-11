#!/usr/bin/env python3
"""
从 play_song.c 提取歌词汉字，从 Hzk16.coe 提取对应字库，
生成精简的中文字库 .mem 文件和查找表。
"""
import re, os

# ===== 1. 从 play_song.c 提取歌词 =====
c_path = r"D:\chlor\Desktop\project_next\test_interrupt\play_song.c"
hzk_path = r"D:\chlor\Desktop\VGA接口\Hzk16.coe"
out_dir = r"D:\chlor\Desktop\project_next\project_next.srcs\sources_1\new"

with open(c_path, 'r', encoding='utf-8') as f:
    c_code = f.read()

# 提取所有歌词行 (中文引号 \u201c \u201d)
lyric_lines = []
for m in re.finditer(r'//从现在开始，歌词[：:]\u201c([^\u201d]*)\u201d', c_code):
    lyric_lines.append(m.group(1))

print("Lyrics found:", len(lyric_lines))
for i, line in enumerate(lyric_lines):
    print(f"  [{i+1}] {line}")

# 手动定义歌曲信息和前奏提示
song_info_lines = [
    "\u300a\u7275\u4e1d\u620f\u300b\u94f6\u4e34/Aki\u6770\u6770",
    "\u4f5c\u8bcdVagary \u4f5c\u66f2\u94f6\u4e34",
    "\u7f16\u66f2\u7070\u539f\u7a77",
]
intro_text = "\u524d\u594f"  # 前奏

# 所有需要显示的文本
all_texts = [intro_text] + lyric_lines + song_info_lines

# 提取所有唯一非ASCII字符
all_chars = set()
for text in all_texts:
    for ch in text:
        if ord(ch) > 127:
            all_chars.add(ch)

char_list = sorted(all_chars, key=lambda c: (c not in '\u300a\u300b', c))
print(f"\nUnique chars: {len(char_list)}")
for i, ch in enumerate(char_list):
    print(f"  [{i:3d}] U+{ord(ch):04X} {ch}")

# ===== 2. GB2312 编码 =====
def char_to_gb2312(ch):
    try:
        encoded = ch.encode('gb2312')
        if len(encoded) == 2:
            return encoded[0], encoded[1]
    except:
        pass
    return None, None

# ===== 3. 解析 Hzk16.coe =====
with open(hzk_path, 'r', encoding='utf-8') as f:
    coe_text = f.read()

hex_vals = re.findall(r'[0-9A-Fa-f]{4}', coe_text)
CHARS_TOTAL = len(hex_vals) // 32
print(f"\nHzk16: {CHARS_TOTAL} chars, {len(hex_vals)} words")

# ===== 4. 提取字库 =====
char_font_data = {}
missing = []
for ch in char_list:
    b1, b2 = char_to_gb2312(ch)
    if b1 is None:
        missing.append(ch)
        continue
    section = b1 - 0xA1
    position = b2 - 0xA1
    if section < 0 or section >= 87 or position < 0 or position >= 94:
        missing.append(ch)
        continue
    offset = (section * 94 + position) * 32
    if offset + 32 > len(hex_vals):
        missing.append(ch)
        continue
    char_font_data[ch] = hex_vals[offset:offset+32]

if missing:
    print(f"Missing: {missing}")
print(f"Extracted: {len(char_font_data)} chars")

# ===== 5. 生成中文字库 .mem =====
font_mem_path = os.path.join(out_dir, "hzk16_custom.mem")
with open(font_mem_path, 'w', encoding='utf-8') as f:
    for ch in char_list:
        if ch in char_font_data:
            for val in char_font_data[ch]:
                f.write(val.upper() + '\n')
        else:
            for _ in range(32):
                f.write('0000\n')
print(f"Generated: {font_mem_path} ({len(char_list)*32} words)")

# ===== 6. 构建歌词数据 =====
# 每条歌词 -> 字符索引列表
def text_to_indices(text):
    return [char_list.index(ch) for ch in text if ch in char_list]

lyrics_data = []
lyrics_data.append(text_to_indices(intro_text))  # 0: 前奏
for line in lyric_lines:
    lyrics_data.append(text_to_indices(line))
# 歌曲信息 (最后3条)
for info in song_info_lines:
    lyrics_data.append(text_to_indices(info))

# 生成歌词索引mem
# 格式: 每条8字节 = start_addr(16bit) + len(16bit)
# start_addr = 字符在hzk16_custom.mem中的起始word地址 = index * 32
lyrics_mem_path = os.path.join(out_dir, "lyrics_index.mem")
with open(lyrics_mem_path, 'w', encoding='utf-8') as f:
    for indices in lyrics_data:
        if indices:
            start_word = indices[0] * 32  # 起始word地址
            length = len(indices)
            f.write(f'{start_word:04X}\n')
            f.write(f'{length:04X}\n')
        else:
            f.write('0000\n')
            f.write('0000\n')
print(f"Generated: {lyrics_mem_path}")

# ===== 7. 输出汇总 =====
print("\n===== Summary =====")
print(f"Total lyrics entries: {len(lyrics_data)}")
for i, indices in enumerate(lyrics_data):
    text = ''.join([char_list[idx] for idx in indices])
    print(f"  [{i:2d}] ({len(indices):2d} chars) {text}")

# 生成歌词文本文件
lyrics_txt_path = os.path.join(out_dir, "lyrics_table.txt")
with open(lyrics_txt_path, 'w', encoding='utf-8') as f:
    f.write(f"Total chars: {len(char_list)}\n")
    f.write(f"Total lyrics: {len(lyrics_data)}\n\n")
    f.write("Char table:\n")
    for i, ch in enumerate(char_list):
        gb = char_to_gb2312(ch)
        f.write(f"  [{i:3d}] U+{ord(ch):04X} GB={gb} {ch}\n")
    f.write("\nLyrics index:\n")
    for i, indices in enumerate(lyrics_data):
        text = ''.join([char_list[idx] for idx in indices])
        start = indices[0] * 32 if indices else 0
        f.write(f"  [{i:2d}] start_word={start:5d} len={len(indices):2d} | {text}\n")
print(f"Generated: {lyrics_txt_path}")
