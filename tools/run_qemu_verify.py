# ============================================================================
#  run_qemu_verify.py — QEMU 自动化验证脚本（LPY-DOS）
#  方案（与 .trae/specs/add-component-logos/verify_about.ps1 一致）：
#    - QEMU 无显示启动，monitor 走 TCP
#    - sendkey 注入按键执行外部 .COM 程序
#    - pmemsave 读取 VGA 显存解析文本验证输出
#  每次命令触发一次 EXEC -> mc_alloc -> mc_free。
#  若 MCB 链损坏，后续命令将失败并打印 "Bad command or file name"，
#  或系统卡死（无法返回新提示符）。
#
#  用法：python tools/run_qemu_verify.py
#  Copyright (C) 2026 Nexlyh
# ============================================================================
import subprocess
import sys
import time
import os
import socket

IMG = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'LPY-DOS.img'))
QEMU = 'qemu-system-i386.exe'
PORT = 45658
MEM = os.path.join(os.path.dirname(__file__), 'vga_dump.bin').replace('\\', '/')
OUTTXT = os.path.join(os.path.dirname(__file__), 'verify_screen.txt')

# 命令序列：每条命令一次 EXEC（含内置命令 dir / ver 以触发执行路径）
CMDS = ['hello', 'hello', 'calc', 'ver', 'hello', 'factor 100', 'hello', 'dir']

KEYMAP = {' ': 'spc', '.': 'dot'}


def main():
    proc = subprocess.Popen(
        [QEMU, '-fda', IMG, '-boot', 'a', '-display', 'none', '-vga', 'std',
         '-monitor', f'tcp:127.0.0.1:{PORT},server,nowait', '-serial', 'none'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(4)
    s = socket.create_connection(('127.0.0.1', PORT), timeout=5)
    time.sleep(0.3)

    def mon(line, slp=0.12):
        s.sendall((line + '\r\n').encode())
        time.sleep(slp)

    def dump():
        try:
            if os.path.exists(MEM):
                os.remove(MEM)
        except OSError:
            pass
        mon(f'pmemsave 0xb8000 0x1000 "{MEM}"', slp=0.35)
        try:
            with open(MEM, 'rb') as f:
                raw = f.read(0x1000)
        except OSError:
            return ''
        return ''.join(chr(c) if 32 <= c < 127 else ' ' for c in raw[0::2])

    def screen_joined():
        t = dump()
        return '\n'.join(t[r*80:(r+1)*80].rstrip() for r in range(25))

    def type_cmd(cmd):
        for ch in cmd:
            mon(f'sendkey {KEYMAP.get(ch, ch)}', slp=0.05)
        mon('sendkey ret', slp=0.05)

    log = ['=== LPY-DOS EXEC 循环验证 ===']
    all_ok = True
    try:
        # 等待 shell 提示符
        prompt_ok = False
        for _ in range(30):
            if 'C:\\>' in screen_joined():
                prompt_ok = True
                break
            time.sleep(0.5)
        log.append(f'[1] shell 提示符出现: {"PASS" if prompt_ok else "FAIL"}')
        if not prompt_ok:
            all_ok = False

        # 依次执行命令
        for i, cmd in enumerate(CMDS):
            type_cmd(cmd)
            time.sleep(2.0)
            joined = screen_joined()
            # 回显检查：命令名出现在屏幕（被接受执行）
            echo_ok = cmd.split()[0] in joined
            # 无错误消息
            err_free = ('Bad command' not in joined) and ('not found' not in joined)
            # 系统仍存活：能显示提示符
            alive = 'C:\\>' in joined
            if echo_ok and err_free and alive:
                log.append(f'[{i+2}] {cmd}: PASS (回显+无错误+提示符)')
            else:
                log.append(f'[{i+2}] {cmd}: FAIL (echo={echo_ok} err_free={err_free} alive={alive})')
                all_ok = False
    except Exception as e:
        log.append(f'ERR {e}')
        all_ok = False
    finally:
        try:
            mon('quit', slp=0.1)
        except Exception:
            pass
        try:
            s.close()
        except Exception:
            pass
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()

    # 最终屏幕
    log.append('=== 最终屏幕 ===')
    try:
        log.append(screen_joined())
    except Exception:
        pass

    with open(OUTTXT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(log))
    print('RESULT:', 'ALL_PASS' if all_ok else 'HAS_FAILURE')
    print('screen written:', OUTTXT)
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main())
