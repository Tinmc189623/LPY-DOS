# ============================================================================
#  show_verify.py — 过滤 ANSI 后打印 verify_out.txt 尾部关键内容
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import re, sys, io

path = sys.argv[1] if len(sys.argv) > 1 else 'tools/verify_out.txt'
raw = open(path, encoding='utf-8', errors='replace').read()
ansi = re.compile(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][0-9A-B]|\x1b[=>]|\x1b\][^\x07]*\x07|[\x00-\x08\x0b-\x1f\x7f]')
clean = ansi.sub('', raw)
# 折叠连续空白
clean = re.sub(r'[ \t]+', ' ', clean)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
print(clean)
