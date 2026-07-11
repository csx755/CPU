#!/usr/bin/env python3
"""生成歌词字符索引数据 (给VGA模块用)"""
import re, os

c_path = r"D:\chlor\Desktop\project_next\test_interrupt\play_song.c"
out_dir = r"D:\chlor\Desktop\project_next\project_next.srcs\sources_1\new"

with open(c_path, 'r', encoding='utf-8') as f:
    c_code = f.read()

# 提取歌词
lyric_lines = []
for m in re.finditer(r'//从现在开始，歌词[：:]\u201c([^\u201d]*)\u201d', c_code):
    lyric_lines.append(m.group(1))

# 直接硬编码字符表 (从lyrics_table.txt复制)
char_list = list("《》一万不与世丝临为了事他们似何作你侍入兰分别前却原只台合吹吻和哪唱喜嘲回墨声处天奏好如威媚完对尘尺山岁帷幕年并幽开彩得微心悲悴愿憔戏成我才扬指捻支明是曲更替最有杰染歌水没泪清演火灯灰牵珠生由的盘相眼角离穷竟笑笔算红绘编罪美肩脆花行褴褛角记词误谁迂过遇配铃银问间")

# 手动定义歌词
intro = "前奏"
song_info = [
    "《牵丝戏》银临/Aki阿杰",
    "作词Vagary 作曲银临",
    "编曲灰原穷",
]

all_lyrics = [intro] + lyric_lines + song_info

# 转换为字符索引
def to_indices(text):
    result = []
    for ch in text:
        if ch in char_list:
            result.append(char_list.index(ch))
        else:
            result.append(-1)
    return result

lyrics_indices = [to_indices(line) for line in all_lyrics]

# 验证
for i, (line, indices) in enumerate(zip(all_lyrics, lyrics_indices)):
    recovered = ''.join([char_list[idx] if idx >= 0 else '?' for idx in indices])
    ok = "OK" if all(idx >= 0 for idx in indices) else "MISSING"
    print(f"  [{i:2d}] {ok:7s} {line} -> {recovered}")

# ===== 生成 lyrics_chars.mem =====
flat_path = os.path.join(out_dir, "lyrics_chars.mem")
total = 0
with open(flat_path, 'w', encoding='utf-8') as f:
    for indices in lyrics_indices:
        for idx in indices:
            f.write(f'{idx & 0xFFFF:04X}\n')
            total += 1
print(f"\nlyrics_chars.mem: {total} entries")

# ===== 生成 lyrics_offset.mem =====
offset_path = os.path.join(out_dir, "lyrics_offset.mem")
running = 0
with open(offset_path, 'w', encoding='utf-8') as f:
    for indices in lyrics_indices:
        f.write(f'{running:04X}\n')
        f.write(f'{len(indices):04X}\n')
        running += len(indices)
print(f"lyrics_offset.mem: {len(lyrics_indices)} entries, {running} total chars")
