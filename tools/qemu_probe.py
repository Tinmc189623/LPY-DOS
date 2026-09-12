# ============================================================================
#  qemu_probe.py — 探测 QEMU nographic 模式下输入/输出行为
#  输出写入 probe_out.txt，避免控制台编码问题
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import subprocess, sys, time, os, threading, queue

IMG = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'LPY-DOS.img'))
OUT = os.path.join(os.path.dirname(__file__), 'probe_out.txt')
proc = subprocess.Popen(
    ['qemu-system-i386.exe', '-fda', IMG, '-boot', 'a', '-nographic', '-monitor', 'none'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)

q = queue.Queue()
def reader():
    try:
        while True:
            b = proc.stdout.read(1)
            if not b: break
            q.put(b.decode('latin-1','replace'))
    except Exception: pass
threading.Thread(target=reader, daemon=True).start()

def drain(sec):
    buf=[]
    end=time.time()+sec
    while time.time()<end:
        try:
            buf.append(q.get(timeout=0.05))
        except queue.Empty: pass
    return ''.join(buf)

log = []
log.append('--- 启动后 3 秒输出 ---\n')
log.append(drain(3))
log.append('\n--- 发送 ver 回车 ---\n')
proc.stdin.write(b'ver\r'); proc.stdin.flush()
log.append(drain(4))
log.append('\n--- 发送 hello 回车 ---\n')
proc.stdin.write(b'hello\r'); proc.stdin.flush()
log.append(drain(4))
try: proc.stdin.close()
except Exception: pass
try: proc.wait(timeout=3)
except Exception: proc.kill()

with open(OUT, 'w', encoding='utf-8') as f:
    f.write(''.join(log))
print('done, wrote', OUT)
