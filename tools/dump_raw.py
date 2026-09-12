# ============================================================================
#  dump_raw.py — 打印原始文件的全部内容（latin-1 解码后转 utf-8 输出）
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import sys, io

path = sys.argv[1] if len(sys.argv) > 1 else 'tools/verify_out.txt'
raw = open(path, encoding='utf-8', errors='replace').read()
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
# 只打印所有可打印字符（保留 \n \r），丢弃控制字符
out = []
for ch in raw:
    o = ord(ch)
    if ch in '\n\r' or 0x20 <= o <= 0x7E:
        out.append(ch)
print(''.join(out))
