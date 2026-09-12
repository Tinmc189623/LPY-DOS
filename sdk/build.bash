#!/usr/bin/env bash
# ============================================================================
#  LPY-DOS SDK 构建脚本（Bash 版）
#  自动查找 FASM：LPYDOS_FASM -> PATH -> 常见安装路径。
#  找不到则提示安装；找到则编译 sdk/examples 下的示例为 .COM。
#
#  用法：./build.bash [all|hello|app]   默认 all
#  Copyright (C) 2026 Nexsteaduser. Licensed under GPL v3 or later.
# ============================================================================
set -u

EXDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/examples" && pwd)"

# ----------------------------------------------------------------------------
#  find_fasm：定位 FASM，优先返回已存在路径；失败输出空串
# ----------------------------------------------------------------------------
find_fasm() {
    # 1) 环境变量
    if [[ -n "${LPYDOS_FASM:-}" && -e "$LPYDOS_FASM" ]]; then
        echo "$LPYDOS_FASM"; return
    fi
    # 2) PATH
    local c p
    for c in fasm fasm.exe; do
        p="$(command -v "$c" 2>/dev/null)" && [[ -n "$p" ]] && { echo "$p"; return; }
    done
    # 3) 常见安装路径
    local cand=(
        /usr/bin/fasm /usr/local/bin/fasm /opt/fasm/bin/fasm
        "${HOME:-}/fasm/fasm" "${HOME:-}/fasm/fasm.exe"
        "${PROGRAMFILES:-}/fasm/fasm.exe" "${PROGRAMFILES:-}/fasm/fasm.exe"
        /c/FASM/fasm.exe /c/fasm/fasm.exe /d/FASM/fasm.exe "/d/fasm/fasm.exe"
    )
    for p in "${cand[@]}"; do
        [[ -e "$p" ]] && { echo "$p"; return; }
    done
}

FASM="$(find_fasm)"
if [[ -z "$FASM" ]]; then
    echo "[错误] 未找到 FASM 汇编器。" >&2
    echo "  请从 https://flatassembler.net/ 下载并安装。" >&2
    echo "  安装后可用环境变量 LPYDOS_FASM 指定其路径。" >&2
    exit 1
fi
echo "使用 FASM: $FASM"

# ----------------------------------------------------------------------------
#  编译一个源码文件
# ----------------------------------------------------------------------------
build_one() {
    local src="$1" out="${1%.asm}.COM"
    printf '  FASM  %s -> %s\n' "$src" "$(basename "$out")"
    "$FASM" "$src" "$out" || echo "编译失败: $src"
}

TARGET="${1:-all}"
echo "== LPY-DOS SDK 示例构建 =="

if [[ "$TARGET" == all ]]; then
    [[ -d "$EXDIR" ]] || { echo "[错误] 未找到目录 $EXDIR" >&2; exit 1; }
    shopt -s nullglob
    for src in "$EXDIR"/*.asm; do build_one "$src"; done
else
    build_one "$EXDIR/$TARGET.asm"
fi

echo "== 完成。将生成的 .COM 放入系统镜像即可运行。 =="