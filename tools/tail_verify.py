# ============================================================================
#  tail_verify.py — 打印过滤后文本的末尾 N 字符（诊断 shell 状态）
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import re, sys, io

path = sys.argv[1] if len(sys.argv) > 1 else 'tools/verify_out.txt'
raw = open(path, encoding='utf-8', errors='replace').read()
ansi = re.compile(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][0-9A-B]|\x1b[=>]|\x1b\][^\x07]*\x07|[\x00-\x08\x0b-\x1f\x7f]')
clean = ansi.sub('', raw)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
print('LEN', len(clean))
print('==== 尾部 2000 ====')
print(clean[-2000:])
