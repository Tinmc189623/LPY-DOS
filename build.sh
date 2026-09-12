#!/bin/sh
# ============================================================================
#  LPY-DOS 构建脚本（POSIX sh 版，适配 Linux/macOS/BSD 及 WSL 等环境）
#  1. 用 FASM 编译 boot / kernel / shell
#  2. 编译 programs/ 下全部外部 .COM 程序
#  3. 生成 FAT12 1.44MB 软盘镜像 LPY-DOS.img（内核 + shell + 所有程序）
#  4. （可选）启动 QEMU 运行
#
#  用法：./build.sh [run]
#    run 参数表示构建后启动 QEMU
#
#  工具定位顺序（FASM）：
#    环境变量 LPYDOS_FASM -> PATH 中的 fasm -> 常见安装路径
#
#  依赖：sh、dd、od、wc、tr 等 POSIX 工具，以及 fasm 汇编器。
#
#  Copyright (C) 2026 Nexsteaduser
#  This program is free software under the GNU GPL v3 or later.
# ============================================================================
set -u

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd -- "$ROOT" || exit 1

# ----------------------------------------------------------------------------
#  find_fasm：定位 fasm 可执行文件，输出路径；失败返回 1
# ----------------------------------------------------------------------------
find_fasm() {
    if [ -n "${LPYDOS_FASM:-}" ] && [ -e "$LPYDOS_FASM" ]; then
        printf '%s\n' "$LPYDOS_FASM"
        return 0
    fi
    for c in fasm fasm.exe; do
        p=$(command -v "$c" 2>/dev/null) || continue
        [ -n "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    for p in \
        /usr/bin/fasm /usr/local/bin/fasm /opt/fasm/bin/fasm \
        "${HOME:-}/fasm/fasm" "${HOME:-}/fasm/fasm.exe" \
        /c/FASM/fasm.exe /c/fasm/fasm.exe /d/FASM/fasm.exe /d/fasm/fasm.exe \
        /mnt/c/FASM/fasm.exe /mnt/d/FASM/fasm.exe /mnt/d/fasm/fasm.exe
    do
        [ -e "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

# ----------------------------------------------------------------------------
#  镜像几何（与 boot.asm BPB 一致）
# ----------------------------------------------------------------------------
BYPS=512
SPC=1
RSV=1
NFAT=2
ROOTENT=224
TOT=2880
FATSE=9
ROOTSTART=$(( RSV + NFAT * FATSE ))              # 19
ROOTSECTS=$(( (ROOTENT * 32 + BYPS - 1) / BYPS )) # 14
DATASTART=$(( ROOTSTART + ROOTSECTS ))           # 33
FATSZ=$(( FATSE * BYPS ))                        # 4608

IMG="$ROOT/LPY-DOS.img"
WKTMP="$ROOT/.build_sh_tmp"
FATF="$WKTMP/fat.dat"
DIRDAT="$WKTMP/dir.dat"

# ----------------------------------------------------------------------------
#  putc_file <file> <offset> <byte>：向文件指定偏移写入单字节
# ----------------------------------------------------------------------------
putc_file() {
    printf "\\$(printf '%03o' "$3")" \
        | dd conv=notrunc of="$1" bs=1 seek="$2" count=1 2>/dev/null
}

# ----------------------------------------------------------------------------
#  read_byte <file> <offset>：读取单字节十进制值
# ----------------------------------------------------------------------------
read_byte() {
    od -An -tu1 -j "$2" -N 1 "$1" | tr -d ' '
}

# ----------------------------------------------------------------------------
#  set_fat <fatfile> <cluster> <val>：写一个 FAT12 簇项
# ----------------------------------------------------------------------------
set_fat() {
    f=$1; n=$2; val=$3
    off=$(( n + n / 2 ))
    if [ $(( n % 2 )) -eq 0 ]; then
        b1=$(read_byte "$f" $(( off + 1 )))
        [ -z "$b1" ] && b1=0
        putc_file "$f" $(( off ))     $(( val & 0xFF ))
        putc_file "$f" $(( off + 1 )) $(( (b1 & 0xF0) | ((val >> 8) & 0x0F) ))
    else
        b0=$(read_byte "$f" "$off")
        [ -z "$b0" ] && b0=0
        putc_file "$f" "$off"         $(( (b0 & 0x0F) | ((val & 0x0F) << 4) ))
        putc_file "$f" $(( off + 1 )) $(( (val >> 4) & 0xFF ))
    fi
}

# ----------------------------------------------------------------------------
#  name11 <stem> <ext>：构造成 8.3 短名（11 字节）
# ----------------------------------------------------------------------------
name11() {
    s=$(printf '%s\n' "$1" | tr '[:lower:]' '[:upper:]')
    e=$(printf '%s\n' "$2" | tr '[:lower:]' '[:upper:]')
    printf '%-8.8s%-3.3s' "$s" "$e"
}

# ----------------------------------------------------------------------------
#  build_dirent <file> <name11> <attr> <cluster> <size>：生成 32 字节目录项
# ----------------------------------------------------------------------------
build_dirent() {
    d=$1; name=$2; attr=$3; clu=$4; sz=$5
    rm -f -- "$d"
    printf '%s' "$name"                 >> "$d"
    printf "\\$(printf '%03o' "$attr")" >> "$d"
    dd if=/dev/zero bs=1 count=14 2>/dev/null >> "$d"
    printf "\\$(printf '%03o' $(( clu & 0xFF )))\\$(printf '%03o' $(( (clu >> 8) & 0xFF )))" >> "$d"
    printf "\\$(printf '%03o' $(( sz & 0xFF )))\\$(printf '%03o' $(( (sz >> 8) & 0xFF )))\\$(printf '%03o' $(( (sz >> 16) & 0xFF )))\\$(printf '%03o' $(( (sz >> 24) & 0xFF )))" >> "$d"
}

# ----------------------------------------------------------------------------
#  分配簇链、写根目录项与数据区
# ----------------------------------------------------------------------------
nextclu=2
datapos=0
diridx=0

process_file() { # <name11> <filepath>
    name=$1; path=$2
    size=$(wc -c < "$path" | tr -d ' ')
    n=$(( (size + BYPS - 1) / BYPS ))
    [ "$n" -lt 1 ] && n=1
    clbase=$nextclu
    k=0
    while [ "$k" -lt "$n" ]; do
        clu=$(( clbase + k ))
        if [ "$k" -eq $(( n - 1 )) ]; then val=$((0xFFF)); else val=$(( clu + 1 )); fi
        set_fat "$FATF" "$clu" "$val"
        k=$(( k + 1 ))
    done
    build_dirent "$DIRDAT" "$name" $((0x20)) "$clbase" "$size"
    dd conv=notrunc of="$IMG" bs=1 seek=$(( ROOTSTART * BYPS + diridx * 32 )) count=32 if="$DIRDAT" 2>/dev/null
    dd conv=notrunc of="$IMG" bs="$BYPS" seek=$(( DATASTART + datapos )) count=$(( (size + BYPS - 1) / BYPS )) if="$path" 2>/dev/null
    datapos=$(( datapos + n ))
    nextclu=$(( nextclu + n ))
    diridx=$(( diridx + 1 ))
}

# ----------------------------------------------------------------------------
#  main
# ----------------------------------------------------------------------------
FASM=$(find_fasm)
if [ -z "$FASM" ]; then
    echo "[错误] 未找到 FASM 汇编器。" >&2
    echo "  请从 https://flatassembler.net/ 下载并安装。" >&2
    echo "  安装后可用环境变量 LPYDOS_FASM 指定其路径。" >&2
    exit 1
fi
echo "使用 FASM: $FASM"

echo '== LPY-DOS 构建 =========================================='

echo '[1/3] 编译引导扇区'
"$FASM" boot/boot.asm boot/boot.bin || exit 1

echo '[2/3] 编译内核 LPYOS.SYS'
"$FASM" kernel/kernel.asm LPYOS.SYS || exit 1

echo '[3/3] 编译命令解释器 LPYCMD.COM'
"$FASM" shell/shell.asm LPYCMD.COM || exit 1

echo '[*]   编译 programs/*.asm（外部 .COM 程序）'
for src in programs/*.asm; do
    out=${src%.asm}   # 保留相对路径目录
    echo "  FASM  $src"
    "$FASM" "$src" "$out.COM" || exit 1
done

bootsz=$(wc -c < boot/boot.bin | tr -d ' ')
kernsz=$(wc -c < LPYOS.SYS | tr -d ' ')
if [ "$bootsz" -gt "$BYPS" ]; then
    echo "[错误] boot.bin 超过 512 字节" >&2
    exit 1
fi
if [ "$kernsz" -gt 32768 ]; then
    echo "[错误] LPYOS.SYS 超过 32KB（引导扇区无法加载）" >&2
    exit 1
fi

echo '== 生成 FAT12 镜像 ======================================='
rm -rf -- "$WKTMP"
mkdir -p -- "$WKTMP"

rm -f -- "$IMG"
dd if=/dev/zero of="$IMG" bs="$BYPS" count="$TOT" 2>/dev/null

# 引导扇区
dd conv=notrunc of="$IMG" bs="$BYPS" seek=0 count=$(( (bootsz + BYPS - 1) / BYPS )) if=boot/boot.bin 2>/dev/null

# 初始化 FAT（保留簇 0/1）
dd if=/dev/zero of="$FATF" bs="$FATSZ" count=1 2>/dev/null
putc_file "$FATF" 0 $((0xF0))
putc_file "$FATF" 1 $((0xFF))
putc_file "$FATF" 2 $((0xFF))

# 分配：内核 + shell + programs/*.COM
process_file "$(name11 LPYOS SYS)" "$ROOT/LPYOS.SYS"
process_file "$(name11 LPYCMD COM)" "$ROOT/LPYCMD.COM"
for com in "$ROOT"/programs/*.COM; do
    base=${com%.COM}
    base=${base##*/}
    process_file "$(name11 "$base" COM)" "$com"
done

# 两份 FAT 写入镜像（FATSZ 为 512 整数倍）
dd conv=notrunc of="$IMG" bs="$BYPS" seek=$RSV count=$(( FATSZ / BYPS )) if="$FATF" 2>/dev/null
dd conv=notrunc of="$IMG" bs="$BYPS" seek=$(( RSV + FATSE )) count=$(( FATSZ / BYPS )) if="$FATF" 2>/dev/null

rm -rf -- "$WKTMP"

echo "  镜像已生成: $IMG ($(( BYPS * TOT )) 字节)"
echo "  共写入 $diridx 个文件，占用 $(( nextclu - 2 )) 簇"

# ----------------------------------------------------------------------------
#  可选用：启动 QEMU
# ----------------------------------------------------------------------------
if [ $# -gt 0 ] && [ "$1" = "run" ]; then
    echo '== 启动 QEMU ============================================'
    if QEMU=$(command -v qemu-system-i386 2>/dev/null); then
        "$QEMU" -fda "$IMG" -boot a
    else
        echo '未找到 QEMU，请安装 QEMU 后手动运行：'
        echo "  qemu-system-i386 -fda $IMG -boot a"
    fi
fi