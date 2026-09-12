# ============================================================================
#  inspect2.py — 在原始与过滤文本中搜索命令回显痕迹
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import re, sys, io

path = sys.argv[1] if len(sys.argv) > 1 else 'tools/verify_out.txt'
raw = open(path, encoding='utf-8', errors='replace').read()
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

for pat in ['ver', 'hello', 'calc', 'factor', 'World', 'COMMAND', 'Bad', 'not found',
            'GPL', 'free software', '1.0.0', 'Syntax', 'usage']:
    print(pat, '=>', raw.count(pat))
