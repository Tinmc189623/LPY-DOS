#!/bin/sh
# ============================================================================
#  LPY-DOS SDK 构建脚本（POSIX sh 版）
#  自动查找 FASM 汇编器：环境变量 LPYDOS_FASM -> PATH -> 常见安装路径。
#  找不到则提示安装；找到则用其编译 sdk/examples 下的示例为 .COM。
#
#  用法：./build.sh [all|hello|app]   默认 all
#  Copyright (C) 2026 Nexsteaduser. Licensed under GPL v3 or later.
# ============================================================================
set -u

# 示例源码目录（以脚本位置为基准）
EXDIR="$(CDPATH= cd -- "$(dirname -- "$0")/examples" && pwd)"

# ----------------------------------------------------------------------------
#  find_fasm：定位 fasm 可执行文件，输出路径；失败返回 1
# ----------------------------------------------------------------------------
find_fasm() {
    # 1) 环境变量优先
    if [ -n "${LPYDOS_FASM:-}" ] && [ -e "$LPYDOS_FASM" ]; then
        printf '%s\n' "$LPYDOS_FASM"
        return 0
    fi
    # 2) PATH 内查找
    for c in fasm fasm.exe; do
        p="$(command -v "$c" 2>/dev/null)" || continue
        [ -n "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    # 3) 常见安装路径
    for p in \
        /usr/bin/fasm /usr/local/bin/fasm /opt/fasm/bin/fasm \
        "${HOME:-}/fasm/fasm" "${HOME:-}/fasm/fasm.exe" \
        /c/FASM/fasm.exe /c/fasm/fasm.exe /d/FASM/fasm.exe "/d/fasm/fasm.exe"
    do
        [ -e "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

FASM="$(find_fasm)"
if [ -z "$FASM" ]; then
    echo "[错误] 未找到 FASM 汇编器。" >&2
    echo "  请从 https://flatassembler.net/ 下载并安装。" >&2
    echo "  安装后可用环境变量 LPYDOS_FASM 指定其路径。" >&2
    exit 1
fi
echo "使用 FASM: $FASM"

# ----------------------------------------------------------------------------
#  选择编译目标
# ----------------------------------------------------------------------------
TARGET="${1:-all}"
if [ "$TARGET" = "all" ]; then
    [ -d "$EXDIR" ] || { echo "[错误] 未找到目录 $EXDIR" >&2; exit 1; }
    set -- "$EXDIR"/*.asm
else
    set -- "$EXDIR/$TARGET.asm"
fi

# ----------------------------------------------------------------------------
#  逐个编译（输出到示例目录同名 .COM）
# ----------------------------------------------------------------------------
echo "== LPY-DOS SDK 示例构建 =="
for src do
    out="${src%.asm}.COM"
    printf '  FASM  %s -> %s\n' "$src" "$(basename -- "$out")"
    "$FASM" "$src" "$out" || echo "编译失败: $src"
done
echo "== 完成。将生成的 .COM 放入系统镜像即可运行。 =="