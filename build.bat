@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo   Nexsteaduser OS Build System
echo   Version: Beta-0.2.0.3
echo ==========================================
echo.

:: 颜色定义
set "COLOR_RED=[91m"
set "COLOR_GREEN=[92m"
set "COLOR_YELLOW=[93m"
set "COLOR_BLUE=[94m"
set "COLOR_CYAN=[96m"
set "COLOR_RESET=[0m"

:: 构建统计
set BUILD_COUNT=0
set BUILD_START_TIME=%TIME%

:: 日志函数
:log_info
echo %COLOR_CYAN%[INFO]%COLOR_RESET% %~1
goto :eof

:log_success
echo %COLOR_GREEN%[OK]%COLOR_RESET% %~1
goto :eof

:log_warning
echo %COLOR_YELLOW%[WARN]%COLOR_RESET% %~1
goto :eof

:log_error
echo %COLOR_RED%[ERROR]%COLOR_RESET% %~1
goto :eof

:: 计算时间差
:calculate_time
set "END_TIME=%TIME%"
set "START_TIME=%~1"

:: 解析开始时间
for /f "tokens=1-3 delims=:." %%a in ("%START_TIME%") do (
    set "START_HOURS=%%a"
    set "START_MINUTES=%%b"
    set "START_SECONDS=%%c"
)

:: 解析结束时间
for /f "tokens=1-3 delims=:." %%a in ("%END_TIME%") do (
    set "END_HOURS=%%a"
    set "END_MINUTES=%%b"
    set "END_SECONDS=%%c"
)

:: 计算时间差（简化计算）
set /a "TOTAL_SECONDS=(%END_HOURS% - %START_HOURS%) * 3600 + (%END_MINUTES% - %START_MINUTES%) * 60 + (%END_SECONDS% - %START_SECONDS%)"
if %TOTAL_SECONDS% LSS 0 set /a "TOTAL_SECONDS+=86400"
goto :eof

:: 清理构建
:clean_build
call :log_info "清理构建环境..."

:: 清理构建产物
if exist bootloader\target rmdir /s /q bootloader\target
if exist kernel\target rmdir /s /q kernel\target
if exist iso rmdir /s /q iso

:: 清理日志文件
if exist build.log del build.log
if exist nexsteaduser-os.iso del nexsteaduser-os.iso

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=清理完成
call :log_success "构建环境清理完成"
goto :eof

:: 检查依赖
:check_dependencies
call :log_info "检查构建依赖..."

set MISSING_DEPS=

:: 检查Rust
where cargo >nul 2>&1
if %ERRORLEVEL% NEQ 0 set MISSING_DEPS=%MISSING_DEPS% cargo

:: 检查GRUB工具
where grub-mkrescue >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    where xorriso >nul 2>&1
    if %ERRORLEVEL% NEQ 0 set MISSING_DEPS=%MISSING_DEPS% grub-mkrescue 或 xorriso
)

:: 检查QEMU（可选）
where qemu-system-x86_64 >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :log_warning "QEMU未找到，将无法测试ISO文件"
)

if not "%MISSING_DEPS%"=="" (
    call :log_error "缺少依赖: %MISSING_DEPS%"
    call :log_error "请安装缺少的依赖后再试"
    exit /b 1
)

call :log_success "所有依赖检查通过"
goto :eof

:: 构建bootloader
:build_bootloader
call :log_info "构建bootloader..."

cd bootloader

:: 记录开始时间
set "BOOTLOADER_START_TIME=%TIME%"

:: 构建bootloader
cargo build --release --target x86_64-nexsteaduser-os.json
if %ERRORLEVEL% NEQ 0 (
    call :log_error "Bootloader构建失败"
    cd ..
    exit /b 1
)

:: 记录结束时间
set "BOOTLOADER_END_TIME=%TIME%"
call :calculate_time "%BOOTLOADER_START_TIME%"

cd ..

:: 验证构建产物
if not exist "bootloader\target\x86_64-nexsteaduser-os\release\bootloader.bin" (
    call :log_error "Bootloader二进制文件未找到"
    exit /b 1
)

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=Bootloader构建成功 (!TOTAL_SECONDS!秒)
call :log_success "Bootloader构建完成 (!TOTAL_SECONDS!秒)"
goto :eof

:: 构建内核
:build_kernel
call :log_info "构建内核..."

cd kernel

:: 记录开始时间
set "KERNEL_START_TIME=%TIME%"

:: 构建内核
cargo build --release --target x86_64-nexsteaduser-os.json
if %ERRORLEVEL% NEQ 0 (
    call :log_error "内核构建失败"
    cd ..
    exit /b 1
)

:: 记录结束时间
set "KERNEL_END_TIME=%TIME%"
call :calculate_time "%KERNEL_START_TIME%"

cd ..

:: 验证构建产物
if not exist "kernel\target\x86_64-nexsteaduser-os\release\nexsteaduser-kernel.bin" (
    call :log_error "内核二进制文件未找到"
    exit /b 1
)

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=内核构建成功 (!TOTAL_SECONDS!秒)
call :log_success "内核构建完成 (!TOTAL_SECONDS!秒)"
goto :eof

:: 创建ISO结构
:create_iso_structure
call :log_info "创建ISO文件结构..."

:: 创建必要的目录
if not exist iso\boot\grub mkdir iso\boot\grub
if not exist iso\ai mkdir iso\ai
if not exist iso\python mkdir iso\python
if not exist iso\docs mkdir iso\docs
if not exist iso\system mkdir iso\system

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=ISO结构创建成功
call :log_success "ISO文件结构创建完成"
goto :eof

:: 复制文件到ISO
:copy_files
call :log_info "复制文件到ISO..."

set MISSING_FILES=

:: 复制bootloader
if exist "bootloader\target\x86_64-nexsteaduser-os\release\bootloader.bin" (
    copy "bootloader\target\x86_64-nexsteaduser-os\release\bootloader.bin" iso\boot\ >nul
) else (
    set MISSING_FILES=%MISSING_FILES% bootloader.bin
)

:: 复制内核
if exist "kernel\target\x86_64-nexsteaduser-os\release\nexsteaduser-kernel.bin" (
    copy "kernel\target\x86_64-nexsteaduser-os\release\nexsteaduser-kernel.bin" iso\boot\ >nul
) else (
    set MISSING_FILES=%MISSING_FILES% nexsteaduser-kernel.bin
)

:: 复制AI库
if exist "python\src\ai_library.py" (
    copy "python\src\ai_library.py" iso\python\ >nul
) else (
    call :log_warning "AI库文件未找到，跳过..."
)

:: 复制Python终端
if exist "python\src\terminal.py" (
    copy "python\src\terminal.py" iso\python\ >nul
) else (
    call :log_warning "Python终端文件未找到，跳过..."
)

:: 复制文档
if exist "docs" (
    copy docs\*.md iso\docs\ >nul 2>&1 || call :log_warning "部分文档文件复制失败"
) else (
    call :log_warning "文档目录未找到，跳过..."
)

:: 复制系统配置
if exist "iso\system\config.ini" (
    copy iso\system\config.ini iso\system\ >nul
) else (
    call :log_warning "系统配置文件未找到，跳过..."
)

if not "%MISSING_FILES%"=="" (
    call :log_error "缺少必要文件: %MISSING_FILES%"
    exit /b 1
)

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=文件复制成功
call :log_success "文件复制完成"
goto :eof

:: 创建GRUB配置
:create_grub_config
call :log_info "创建GRUB配置..."

:: 创建完整的GRUB配置
(
echo set timeout=5
echo set default=0
echo set hidden=0
echo.
echo # Nexsteaduser OS Beta-0.2.0.3 Boot Menu
echo # =====================================
echo.
echo # Full System - Complete installation with all features
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Full System)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin
echo     boot
echo }
echo.
echo # AI Enabled - System with AI features enabled
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (AI Enabled)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin ai=enabled
echo     boot
echo }
echo.
echo # Python Terminal - System with Python terminal interface
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Python Terminal)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin python=terminal
echo     boot
echo }
echo.
echo # Multi-Core Mode - System with multi-core processor support
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Multi-Core Mode)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin smp=enabled
echo     boot
echo }
echo.
echo # USB Support - System with USB device support
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (USB Support)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin usb=enabled
echo     boot
echo }
echo.
echo # Developer Mode - System with developer tools enabled
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Developer Mode)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin dev=enabled
echo     boot
echo }
echo.
echo # Safe Mode - Minimal system for troubleshooting
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Safe Mode)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin safe=mode
echo     boot
echo }
echo.
echo # Debug Mode - System with debug output enabled
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Debug Mode)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin debug=enabled
echo     boot
echo }
echo.
echo # Recovery Mode - System recovery mode
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Recovery Mode)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin recovery=mode
echo     boot
echo }
echo.
echo # Legacy Boot - Fallback boot option
echo menuentry "Nexsteaduser OS Beta-0.2.0.3 (Legacy)" {
echo     multiboot /boot/bootloader.bin
echo     module /boot/nexsteaduser-kernel.bin legacy=boot
echo     boot
echo }
) > iso\boot\grub\grub.cfg

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=GRUB配置创建成功
call :log_success "GRUB配置创建完成"
goto :eof

:: 创建ISO文件
:create_iso
call :log_info "创建ISO文件..."

set ISO_CREATED=false

:: 尝试使用grub-mkrescue
where grub-mkrescue >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    call :log_info "使用grub-mkrescue创建ISO..."
    grub-mkrescue -o nexsteaduser-os.iso iso >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        set ISO_CREATED=true
    ) else (
        call :log_warning "grub-mkrescue失败，尝试xorriso..."
    )
)

:: 尝试使用xorriso
if "%ISO_CREATED%"=="false" (
    where xorriso >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        call :log_info "使用xorriso创建ISO..."
        xorriso -as mkisofs -R -b boot/grub -no-emul-boot -boot-load-size 4 -boot-info-table -o nexsteaduser-os.iso iso >nul 2>&1
        if %ERRORLEVEL% EQU 0 (
            set ISO_CREATED=true
        ) else (
            call :log_error "xorriso创建ISO失败"
            exit /b 1
        )
    ) else (
        call :log_error "无法创建ISO文件，请安装grub-mkrescue或xorriso"
        exit /b 1
    )
)

if "%ISO_CREATED%"=="false" (
    call :log_error "无法创建ISO文件"
    exit /b 1
)

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=ISO创建成功
call :log_success "ISO文件创建完成"
goto :eof

:: 验证ISO文件
:verify_iso
call :log_info "验证ISO文件..."

if not exist "nexsteaduser-os.iso" (
    call :log_error "ISO文件不存在"
    exit /b 1
)

:: 检查文件大小
for %%I in (nexsteaduser-os.iso) do (
    set ISO_SIZE=%%~zI
)
call :log_info "ISO文件大小: !ISO_SIZE! 字节"

:: 检查文件是否为空
if !ISO_SIZE! EQU 0 (
    call :log_error "ISO文件为空"
    exit /b 1
)

:: 检查ISO文件结构（如果isoinfo可用）
where isoinfo >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    call :log_info "检查ISO文件结构..."
    
    :: 检查引导记录
    isoinfo -d -i nexsteaduser-os.iso | findstr /C:"Bootable" >nul
    if %ERRORLEVEL% EQU 0 (
        call :log_success "引导记录检查通过"
    ) else (
        call :log_warning "ISO文件可能没有正确的引导记录"
    )
    
    :: 检查文件结构
    isoinfo -l -i nexsteaduser-os.iso | findstr /C:"/boot/bootloader.bin" >nul
    if %ERRORLEVEL% EQU 0 (
        call :log_success "bootloader.bin验证通过"
    ) else (
        call :log_warning "bootloader.bin未在ISO中找到"
    )
    
    isoinfo -l -i nexsteaduser-os.iso | findstr /C:"/boot/nexsteaduser-kernel.bin" >nul
    if %ERRORLEVEL% EQU 0 (
        call :log_success "nexsteaduser-kernel.bin验证通过"
    ) else (
        call :log_warning "nexsteaduser-kernel.bin未在ISO中找到"
    )
) else (
    call :log_warning "isoinfo不可用，跳过详细验证"
)

set /a BUILD_COUNT+=1
set BUILD_STATS[!BUILD_COUNT!]=ISO验证成功
call :log_success "ISO文件验证完成"
goto :eof

:: 显示构建摘要
:show_summary
call :calculate_time "%BUILD_START_TIME%"

echo.
echo ==========================================
echo            构建摘要
echo ==========================================
echo.

:: 显示构建统计
echo %COLOR_CYAN%构建统计:%COLOR_RESET%
for /l %%i in (1,1,!BUILD_COUNT!) do (
    echo   • !BUILD_STATS[%%i]!
)

echo.

:: 显示ISO文件信息
if exist "nexsteaduser-os.iso" (
    for %%I in (nexsteaduser-os.iso) do (
        set ISO_SIZE=%%~zI
    )
    for %%I in (nexsteaduser-os.iso) do (
        set ISO_DATE=%%~tI
    )
    
    echo %COLOR_GREEN%ISO文件信息:%COLOR_RESET%
    echo   %COLOR_GREEN%文件名:%COLOR_RESET% nexsteaduser-os.iso
    echo   %COLOR_GREEN%大小:%COLOR_RESET%    !ISO_SIZE! 字节
    echo   %COLOR_GREEN%创建时间:%COLOR_RESET% !ISO_DATE!
    echo   %COLOR_GREEN%状态:%COLOR_RESET%    就绪，可引导
    echo.
    
    echo %COLOR_CYAN%启动说明:%COLOR_RESET%
    echo   QEMU:     qemu-system-x86_64 -cdrom nexsteaduser-os.iso -m 512M
    echo   VMware:   创建新虚拟机并选择此ISO文件
    echo   VirtualBox: VBoxManage startvm NexsteaduserOS --type gui
    echo.
    
    echo %COLOR_CYAN%GRUB启动选项:%COLOR_RESET%
    echo   • Full System: 完整系统，包含所有功能
    echo   • AI Enabled: 启用AI功能
    echo   • Python Terminal: Python终端模式
    echo   • Multi-Core Mode: 多核处理器支持
    echo   • USB Support: USB设备支持
    echo   • Developer Mode: 开发者模式
    echo   • Safe Mode: 安全模式（故障排除）
    echo   • Debug Mode: 调试模式
    echo   • Recovery Mode: 恢复模式
    echo   • Legacy Boot: 传统启动（兼容模式）
    
) else (
    echo %COLOR_RED%ISO文件:%COLOR_RESET% 未创建
    echo %COLOR_RED%状态:%COLOR_RESET%  构建失败
)

echo.
echo %COLOR_CYAN%总构建时间:%COLOR_RESET% !TOTAL_SECONDS!秒
echo ==========================================
goto :eof

:: 主函数
:main
if "%1"=="" set "MODE=iso" else set "MODE=%1"

if "%MODE%"=="clean" goto :clean
if "%MODE%"=="check" goto :check
if "%MODE%"=="bootloader" goto :bootloader
if "%MODE%"=="kernel" goto :kernel
if "%MODE%"=="iso" goto :iso
if "%MODE%"=="all" goto :all
if "%MODE%"=="test" goto :test
goto :usage

:clean
call :clean_build
goto :end

:check
call :check_dependencies
goto :end

:bootloader
call :clean_build
call :check_dependencies
call :build_bootloader
goto :end

:kernel
call :clean_build
call :check_dependencies
call :build_kernel
goto :end

:iso
call :clean_build
call :check_dependencies
call :build_bootloader
call :build_kernel
call :create_iso_structure
call :copy_files
call :create_grub_config
call :create_iso
call :verify_iso
call :show_summary
goto :end

:all
call :clean_build
call :check_dependencies
call :build_bootloader
call :build_kernel
call :create_iso_structure
call :copy_files
call :create_grub_config
call :create_iso
call :verify_iso
call :show_summary
goto :end

:test
:: 测试构建（不创建ISO）
call :clean_build
call :check_dependencies
call :build_bootloader
call :build_kernel
call :create_iso_structure
call :copy_files
call :create_grub_config
call :log_success "测试构建完成"
goto :end

:usage
echo 用法: %0 {clean^|check^|bootloader^|kernel^|iso^|all^|test}
echo.
echo 命令:
echo   clean      - 清理构建环境
echo   check      - 检查构建依赖
echo   bootloader - 构建bootloader
echo   kernel     - 构建内核
echo   iso        - 构建完整ISO（默认）
echo   all        - 清理并构建所有内容
echo   test       - 测试构建（不创建ISO）
echo.
echo 示例:
echo   %0 iso      # 构建完整ISO
echo   %0 clean all # 清理并重新构建所有内容
echo   %0 check    # 检查依赖
goto :end

:end
endlocal