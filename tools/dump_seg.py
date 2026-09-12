# ============================================================================
#  dump_seg.py — 打印过滤文本的指定段（诊断）
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import re, sys, io

path = sys.argv[1] if len(sys.argv) > 1 else 'tools/verify_out.txt'
raw = open(path, encoding='utf-8', errors='replace').read()
ansi = re.compile(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][0-9A-B]|\x1b[=>]|\x1b\][^\x07]*\x07|[\x00-\x08\x0b-\x1f\x7f]')
clean = ansi.sub('', raw)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
print(clean)
