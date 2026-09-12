# ============================================================================
#  inspect_verify.py — 诊断 verify_out.txt：查找提示符/重复 banner/异常
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import re, sys, io

path = sys.argv[1] if len(sys.argv) > 1 else 'tools/verify_out.txt'
raw = open(path, encoding='utf-8', errors='replace').read()
ansi = re.compile(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][0-9A-B]|\x1b[=>]|\x1b\][^\x07]*\x07|[\x00-\x08\x0b-\x1f\x7f]')
clean = ansi.sub('', raw)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

print('LEN raw', len(raw), 'LEN clean', len(clean))
print('A:> count:', clean.count('A:>'))
print('A: count:', clean.count('A:'))
print('> count:', clean.count('>'))
print('banner count:', clean.count('LPY-DOS Version'))
print('Bad command:', clean.count('Bad command'))
print('File not found:', clean.count('File not found'))
# 打印首次出现的几个可读标记
for m in ['A:>', 'A:', '>', 'Hello', 'Bad command', 'File not found', 'Directory']:
    idx = clean.find(m)
    if idx >= 0:
        print(f'--- {m} @{idx} ---')
        print(repr(clean[max(0,idx-40):idx+60]))
        break
