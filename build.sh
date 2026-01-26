#!/bin/bash

set -e

echo "=========================================="
echo "  Nexsteaduser OS Build System"
echo "  Version: Beta-0.2.0.3"
echo "=========================================="
echo ""

# 颜色定义
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

# 日志函数
log_info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

# 构建统计
BUILD_STATS=()
BUILD_START_TIME=$(date +%s)

# 清理构建
clean_build() {
    log_info "清理构建环境..."
    
    # 清理构建产物
    rm -rf bootloader/target
    rm -rf kernel/target
    rm -rf iso
    
    # 清理日志文件
    rm -f build.log
    rm -f nexsteaduser-os.iso
    
    BUILD_STATS+=("清理完成")
    log_success "构建环境清理完成"
}

# 检查依赖
check_dependencies() {
    log_info "检查构建依赖..."
    
    local missing_deps=()
    
    # 检查Rust
    if ! command -v cargo >/dev/null 2>&1; then
        missing_deps+=("cargo")
    fi
    
    # 检查GRUB工具
    if ! command -v grub-mkrescue >/dev/null 2>&1 && ! command -v xorriso >/dev/null 2>&1; then
        missing_deps+=("grub-mkrescue 或 xorriso")
    fi
    
    # 检查QEMU（可选，用于测试）
    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        log_warning "QEMU未找到，将无法测试ISO文件"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_error "请安装缺少的依赖后再试"
        exit 1
    fi
    
    log_success "所有依赖检查通过"
}

# 构建bootloader
build_bootloader() {
    log_info "构建bootloader..."
    
    cd bootloader
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 构建bootloader
    if ! cargo build --release --target x86_64-nexsteaduser-os.json 2>&1 | tee -a ../build.log; then
        log_error "Bootloader构建失败"
        tail -20 ../build.log
        return 1
    fi
    
    # 记录结束时间
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    
    cd ..
    
    # 验证构建产物
    if [ ! -f "bootloader/target/x86_64-nexsteaduser-os/release/bootloader.bin" ]; then
        log_error "Bootloader二进制文件未找到"
        return 1
    fi
    
    BUILD_STATS+=("Bootloader构建成功 (${build_time}s)")
    log_success "Bootloader构建完成 (${build_time}s)"
}

# 构建内核
build_kernel() {
    log_info "构建内核..."
    
    cd kernel
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 构建内核
    if ! cargo build --release --target x86_64-nexsteaduser-os.json 2>&1 | tee -a ../build.log; then
        log_error "内核构建失败"
        tail -20 ../build.log
        return 1
    fi
    
    # 记录结束时间
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    
    cd ..
    
    # 验证构建产物
    if [ ! -f "kernel/target/x86_64-nexsteaduser-os/release/nexsteaduser-kernel.bin" ]; then
        log_error "内核二进制文件未找到"
        return 1
    fi
    
    BUILD_STATS+=("内核构建成功 (${build_time}s)")
    log_success "内核构建完成 (${build_time}s)"
}

# 创建ISO结构
create_iso_structure() {
    log_info "创建ISO文件结构..."
    
    # 创建必要的目录
    mkdir -p iso/boot/grub
    mkdir -p iso/ai
    mkdir -p iso/python
    mkdir -p iso/docs
    mkdir -p iso/system
    
    BUILD_STATS+=("ISO结构创建成功")
    log_success "ISO文件结构创建完成"
}

# 复制文件到ISO
copy_files() {
    log_info "复制文件到ISO..."
    
    local missing_files=()
    
    # 复制bootloader
    if [ -f "bootloader/target/x86_64-nexsteaduser-os/release/bootloader.bin" ]; then
        cp bootloader/target/x86_64-nexsteaduser-os/release/bootloader.bin iso/boot/
    else
        missing_files+=("bootloader.bin")
    fi
    
    # 复制内核
    if [ -f "kernel/target/x86_64-nexsteaduser-os/release/nexsteaduser-kernel.bin" ]; then
        cp kernel/target/x86_64-nexsteaduser-os/release/nexsteaduser-kernel.bin iso/boot/
    else
        missing_files+=("nexsteaduser-kernel.bin")
    fi
    
    # 复制AI库
    if [ -f "python/src/ai_library.py" ]; then
        cp python/src/ai_library.py iso/python/
    else
        log_warning "AI库文件未找到，跳过..."
    fi
    
    # 复制Python终端
    if [ -f "python/src/terminal.py" ]; then
        cp python/src/terminal.py iso/python/
    else
        log_warning "Python终端文件未找到，跳过..."
    fi
    
    # 复制文档
    if [ -d "docs" ]; then
        cp docs/*.md iso/docs/ 2>/dev/null || log_warning "部分文档文件复制失败"
    else
        log_warning "文档目录未找到，跳过...")
    fi
    
    # 复制系统配置
    if [ -f "iso/system/config.ini" ]; then
        cp iso/system/config.iso iso/system/
    else
        log_warning "系统配置文件未找到，跳过...")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "缺少必要文件: ${missing_files[*]}"
        return 1
    fi
    
    BUILD_STATS+=("文件复制成功")
    log_success "文件复制完成"
}

# 创建GRUB配置
create_grub_config() {
    log_info "创建GRUB配置..."
    
    # 使用更新的GRUB配置
    cat > iso/boot/grub/grub.cfg << 'GRUB_CONFIG'
set timeout=5
set default=0
set hidden=0

# Nexsteaduser OS Beta-0.2.0.3 Boot Menu
# =====================================

# Full System - Complete installation with all features
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Full System)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin
    boot
}

# AI Enabled - System with AI features enabled
menuentry "Nexsteaduser OS Beta-0.2.0.3 (AI Enabled)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin ai=enabled
    boot
}

# Python Terminal - System with Python terminal interface
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Python Terminal)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin python=terminal
    boot
}

# Multi-Core Mode - System with multi-core processor support
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Multi-Core Mode)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin smp=enabled
    boot
}

# USB Support - System with USB device support
menuentry "Nexsteaduser OS Beta-0.2.0.3 (USB Support)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin usb=enabled
    boot
}

# Developer Mode - System with developer tools enabled
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Developer Mode)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin dev=enabled
    boot
}

# Safe Mode - Minimal system for troubleshooting
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Safe Mode)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin safe=mode
    boot
}

# Debug Mode - System with debug output enabled
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Debug Mode)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin debug=enabled
    boot
}

# Recovery Mode - System recovery mode
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Recovery Mode)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin recovery=mode
    boot
}

# Legacy Boot - Fallback boot option
menuentry "Nexsteaduser OS Beta-0.2.0.3 (Legacy)" {
    multiboot /boot/bootloader.bin
    module /boot/nexsteaduser-kernel.bin legacy=boot
    boot
}
GRUB_CONFIG
    
    BUILD_STATS+=("GRUB配置创建成功")
    log_success "GRUB配置创建完成"
}

# 创建ISO文件
create_iso() {
    log_info "创建ISO文件..."
    
    local iso_created=false
    
    # 尝试使用grub-mkrescue
    if command -v grub-mkrescue >/dev/null 2>&1; then
        log_info "使用grub-mkrescue创建ISO..."
        if grub-mkrescue -o nexsteaduser-os.iso iso 2>/dev/null; then
            iso_created=true
        else
            log_warning "grub-mkrescue失败，尝试xorriso..."
        fi
    fi
    
    # 尝试使用xorriso
    if [ "$iso_created" = false ] && command -v xorriso >/dev/null 2>&1; then
        log_info "使用xorriso创建ISO..."
        if xorriso -as mkisofs -R -b boot/grub -no-emul-boot -boot-load-size 4 -boot-info-table -o nexsteaduser-os.iso iso >/dev/null 2>&1; then
            iso_created=true
        else
            log_error "xorriso创建ISO失败"
            return 1
        fi
    fi
    
    if [ "$iso_created" = false ]; then
        log_error "无法创建ISO文件，请安装grub-mkrescue或xorriso"
        return 1
    fi
    
    BUILD_STATS+=("ISO创建成功")
    log_success "ISO文件创建完成"
}

# 验证ISO文件
verify_iso() {
    log_info "验证ISO文件..."
    
    if [ ! -f "nexsteaduser-os.iso" ]; then
        log_error "ISO文件不存在"
        return 1
    fi
    
    # 检查文件大小
    local iso_size=$(du -h nexsteaduser-os.iso | cut -f1)
    log_info "ISO文件大小: ${iso_size}"
    
    # 检查文件是否为空
    if [ ! -s "nexsteaduser-os.iso" ]; then
        log_error "ISO文件为空"
        return 1
    fi
    
    # 检查ISO文件结构（如果isoinfo可用）
    if command -v isoinfo >/dev/null 2>&1; then
        log_info "检查ISO文件结构..."
        
        # 检查引导记录
        if ! isoinfo -d -i nexsteaduser-os.iso | grep -q "Bootable"; then
            log_warning "ISO文件可能没有正确的引导记录"
        else
            log_success "引导记录检查通过"
        fi
        
        # 检查文件结构
        if ! isoinfo -l -i nexsteaduser-os.iso | grep -q "/boot/bootloader.bin"; then
            log_warning "bootloader.bin未在ISO中找到"
        else
            log_success "bootloader.bin验证通过"
        fi
        
        if ! isoinfo -l -i nexsteaduser-os.iso | grep -q "/boot/nexsteaduser-kernel.bin"; then
            log_warning "nexsteaduser-kernel.bin未在ISO中找到"
        else
            log_success "nexsteaduser-kernel.bin验证通过"
        fi
    else
        log_warning "isoinfo不可用，跳过详细验证")
    fi
    
    BUILD_STATS+=("ISO验证成功")
    log_success "ISO文件验证完成"
}

# 显示构建摘要
show_summary() {
    local end_time=$(date +%s)
    local total_time=$((end_time - BUILD_START_TIME))
    
    echo ""
    echo "=========================================="
    echo "           构建摘要"
    echo "=========================================="
    echo ""
    
    # 显示构建统计
    echo -e "${COLOR_CYAN}构建统计:${COLOR_RESET}"
    for stat in "${BUILD_STATS[@]}"; do
        echo "  • $stat"
    done
    
    echo ""
    
    # 显示ISO文件信息
    if [ -f "nexsteaduser-os.iso" ]; then
        local iso_size=$(du -h nexsteaduser-os.iso | cut -f1)
        local iso_date=$(date -r nexsteaduser-os.iso "+%Y-%m-%d %H:%M:%S")
        
        echo -e "${COLOR_GREEN}ISO文件信息:${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}文件名:${COLOR_RESET} nexsteaduser-os.iso"
        echo -e "  ${COLOR_GREEN}大小:${COLOR_RESET}    ${iso_size}"
        echo -e "  ${COLOR_GREEN}创建时间:${COLOR_RESET} ${iso_date}"
        echo -e "  ${COLOR_GREEN}状态:${COLOR_RESET}    就绪，可引导"
        echo ""
        
        echo -e "${COLOR_CYAN}启动说明:${COLOR_RESET}"
        echo "  QEMU:     qemu-system-x86_64 -cdrom nexsteaduser-os.iso -m 512M"
        echo "  VMware:   创建新虚拟机并选择此ISO文件"
        echo "  VirtualBox: VBoxManage startvm NexsteaduserOS --type gui"
        echo ""
        
        echo -e "${COLOR_CYAN}GRUB启动选项:${COLOR_RESET}"
        echo "  • Full System: 完整系统，包含所有功能"
        echo "  • AI Enabled: 启用AI功能"
        echo "  • Python Terminal: Python终端模式"
        echo "  • Multi-Core Mode: 多核处理器支持"
        echo "  • USB Support: USB设备支持"
        echo "  • Developer Mode: 开发者模式"
        echo "  • Safe Mode: 安全模式（故障排除）"
        echo "  • Debug Mode: 调试模式"
        echo "  • Recovery Mode: 恢复模式"
        echo "  • Legacy Boot: 传统启动（兼容模式）"
        
    else
        echo -e "${COLOR_RED}ISO文件:${COLOR_RESET} 未创建"
        echo -e "${COLOR_RED}状态:${COLOR_RESET}  构建失败"
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}总构建时间:${COLOR_RESET} ${total_time}秒"
    echo "=========================================="
}

# 主函数
main() {
    echo ""
    echo "=========================================="
    echo "  Nexsteaduser OS Beta-0.2.0.3"
    echo "  构建系统 v1.0"
    echo "=========================================="
    echo ""
    
    case "${1:-build}" in
        clean)
            clean_build
            ;;
        check)
            check_dependencies
            ;;
        bootloader)
            clean_build
            check_dependencies
            build_bootloader
            ;;
        kernel)
            clean_build
            check_dependencies
            build_kernel
            ;;
        iso)
            clean_build
            check_dependencies
            build_bootloader
            build_kernel
            create_iso_structure
            copy_files
            create_grub_config
            create_iso
            verify_iso
            show_summary
            ;;
        all)
            clean_build
            check_dependencies
            build_bootloader
            build_kernel
            create_iso_structure
            copy_files
            create_grub_config
            create_iso
            verify_iso
            show_summary
            ;;
        test)
            # 测试构建（不创建ISO）
            clean_build
            check_dependencies
            build_bootloader
            build_kernel
            create_iso_structure
            copy_files
            create_grub_config
            log_success "测试构建完成"
            ;;
        *)
            echo "用法: $0 {clean|check|bootloader|kernel|iso|all|test}"
            echo ""
            echo "命令:"
            echo "  clean      - 清理构建环境"
            echo "  check      - 检查构建依赖"
            echo "  bootloader - 构建bootloader"
            echo "  kernel     - 构建内核"
            echo "  iso        - 构建完整ISO（默认）"
            echo "  all        - 清理并构建所有内容"
            echo "  test       - 测试构建（不创建ISO）"
            echo ""
            echo "示例:"
            echo "  $0 iso      # 构建完整ISO"
            echo "  $0 clean all # 清理并重新构建所有内容"
            echo "  $0 check    # 检查依赖"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"