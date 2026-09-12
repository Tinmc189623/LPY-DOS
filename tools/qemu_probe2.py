# ============================================================================
#  qemu_probe2.py — 最小化 QEMU monitor 探测
#  步骤：启动 -> 连接 -> dump 屏幕 -> 注入 hello -> dump -> quit
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import subprocess, sys, time, os, socket

IMG = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'LPY-DOS.img'))
PORT = 45659
MEM = os.path.join(os.path.dirname(__file__), 'vga2.bin').replace('\\', '/')

proc = subprocess.Popen(
    ['qemu-system-i386.exe', '-fda', IMG, '-boot', 'a', '-display', 'none',
     '-vga', 'std', '-monitor', f'tcp:127.0.0.1:{PORT},server,nowait', '-serial', 'none'],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(4)
s = socket.create_connection(('127.0.0.1', PORT), timeout=5)
time.sleep(0.2)

def mon(line):
    try:
        s.sendall((line + '\r\n').encode())
        time.sleep(0.1)
    except Exception as e:
        print('mon send err', e)

def dump():
    try:
        if os.path.exists(MEM):
            os.remove(MEM)
    except Exception:
        pass
    mon(f'pmemsave 0xb8000 0x1000 "{MEM}"')
    time.sleep(0.4)
    try:
        with open(MEM, 'rb') as f:
            raw = f.read(0x1000)
    except OSError as e:
        print('dump read err', e)
        return ''
    return ''.join(chr(c) if 32 <= c < 127 else ' ' for c in raw[0::2])

# 读初始文本
t = dump()
print('screen0 len', len(t))
print('has C:\\>', 'C:\\>' in t)
print(repr(t[:400]))

# 注入 hello
for ch in 'hello':
    mon(f'sendkey {ch}')
mon('sendkey ret')
time.sleep(2)
t = dump()
print('screen1 has C:\\>', 'C:\\>' in t)
print(repr(t[:400]))

mon('quit')
s.close()
try: proc.wait(timeout=5)
except Exception: proc.kill()
print('done')
