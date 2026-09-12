# ============================================================================
#  run_qemu_diag.py — 分步诊断脚本：每步保存屏幕文本，定位崩溃点
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import subprocess, sys, time, os, socket

IMG = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'LPY-DOS.img'))
PORT = 45660
MEM = os.path.join(os.path.dirname(__file__), 'vga_diag.bin').replace('\\', '/')
OUT = os.path.join(os.path.dirname(__file__), 'diag_steps.txt')

CMDS = ['hello', 'calc', 'ver', 'factor 100', 'dir']
KEYMAP = {' ': 'spc', '.': 'dot'}

proc = subprocess.Popen(
    ['qemu-system-i386.exe', '-fda', IMG, '-boot', 'a', '-display', 'none',
     '-vga', 'std', '-monitor', f'tcp:127.0.0.1:{PORT},server,nowait', '-serial', 'none'],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(4)
s = socket.create_connection(('127.0.0.1', PORT), timeout=5)
time.sleep(0.3)

def mon(line, slp=0.12):
    s.sendall((line + '\r\n').encode())
    time.sleep(slp)

def dump():
    try:
        if os.path.exists(MEM): os.remove(MEM)
    except OSError: pass
    mon(f'pmemsave 0xb8000 0x1000 "{MEM}"', slp=0.35)
    try:
        with open(MEM, 'rb') as f: raw = f.read(0x1000)
    except OSError: return ''
    return ''.join(chr(c) if 32 <= c < 127 else ' ' for c in raw[0::2])

def screen():
    t = dump()
    return '\n'.join(t[r*80:(r+1)*80].rstrip() for r in range(25))

def type_cmd(cmd):
    for ch in cmd:
        mon(f'sendkey {KEYMAP.get(ch, ch)}', slp=0.05)
    mon('sendkey ret', slp=0.05)

log = []
log.append('=== 初始屏幕 ===\n')
log.append(screen() + '\n')
alive = True
for i, cmd in enumerate(CMDS):
    if not alive:
        break
    try:
        type_cmd(cmd)
        time.sleep(2.0)
        sc = screen()
        log.append(f'=== 执行 {cmd} 后 ===\n')
        log.append(sc + '\n')
        if 'C:\\>' not in sc:
            log.append(f'!!! {cmd} 后未回到提示符（疑似崩溃/卡死）\n')
            alive = False
    except Exception as e:
        log.append(f'=== 执行 {cmd} 时连接断开: {e} ===\n')
        alive = False

try:
    mon('quit', slp=0.1)
except Exception: pass
try: s.close()
except Exception: pass
try: proc.wait(timeout=5)
except Exception: proc.kill()

with open(OUT, 'w', encoding='utf-8') as f:
    f.write('\n'.join(log))
print('wrote', OUT)
