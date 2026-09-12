# LPY-DOS

LPY-DOS is an experimental DOS-style operating system for Intel 8086 real mode. The repository contains boot sectors, a kernel, a command interpreter, FAT filesystem support, and executable `.COM` utilities. The project focuses on making the complete BIOS-to-shell path understandable through small assembly modules.

Maintained by Nexsteaduser.

## Project Status

The repository is currently refactoring the boot process into two stages. The v1 FAT12 path, kernel, shell, and external programs remain the main runnable parts. `boot/boot12.asm`, `boot/boot16.asm`, `boot/boot32.asm`, `boot/loadr.asm`, and `boot/mbr.asm` belong to the boot refactor.

The current `build.ps1` and `build.sh` scripts still use the old `boot/boot.asm` entry point, while the new `boot.asm` requires compile-time parameters supplied by a `boot12/16/32.asm` wrapper. The full image build entry point is therefore still being integrated and should not be treated as a released build.

## Features

- 16-bit real-mode assembly built with FASM.
- A kernel loaded at `0x1000:0000`, with disk, FAT, memory, and system-call modules.
- FAT12 support, with source structure for the FAT16/FAT32 boot refactor.
- The `LPYCMD.COM` command interpreter and external `.COM` program execution.
- Text-mode utilities and graphics experiments such as `ggrid`, `gline`, `gmandel`, and `gplasma`.
- `boot/SQBoot.asm`, an emergency boot sector that tries the common FAT32 backup boot sector at LBA 6 and reports a failure before halting.
- BIOS boot-sector layout constrained to 512 bytes and terminated with the `0xAA55` signature.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `boot/` | Boot sectors, shared boot macros, and boot refactor components |
| `kernel/` | Kernel, disk, FAT, memory, graphics, and API modules |
| `shell/` | Command interpreter |
| `programs/` | External `.COM` programs and their assembly sources |
| `sdk/` | SDK headers, examples, and build helpers |
| `docs/` | Requirements, design notes, and implementation records |
| `tools/` | Image and raw-data utilities |
| `build.ps1` | Windows build script |
| `build.sh` | POSIX shell build script |
| `CHANGELOG.md` | Release history |

## Requirements

- PowerShell 7+ is recommended on Windows 11; a compatible POSIX shell can be used on Linux or macOS.
- FASM 1.73 or later on `PATH`. You can also set `LPYDOS_FASM` to the FASM executable path.
- QEMU `qemu-system-i386` is optional and only required to boot an image.

## Quickly Verify the Emergency Boot Sector

`SQBoot.asm` can be assembled independently of the full image build:

```powershell
$fasm = (Get-Command fasm).Source
& $fasm boot\SQBoot.asm $env:TEMP\SQBoot.bin
$bytes = [IO.File]::ReadAllBytes("$env:TEMP\SQBoot.bin")
"size=$($bytes.Length) signature=$('{0:X2} {1:X2}' -f $bytes[510], $bytes[511])"
```

The expected result is `size=512 signature=55 AA`. Verify the target device before writing a boot sector to physical media; raw disk writes can overwrite existing data.

## Build an Image

After the build entry point is synchronized with the two-stage boot refactor, run this on Windows:

```powershell
pwsh -File .\build.ps1
```

All build outputs go to the `bin/` directory (`LPY-DOS.img`, `LPYOS.SYS`, `LPYCMD.COM`, and the `.COM` files under `bin/programs/`; none of them are tracked in git). Boot the generated image with QEMU:

```powershell
qemu-system-i386 -fda .in\LPY-DOS.img -boot a
```

During the current refactor, running the full build directly makes `boot/boot.asm` report a missing `FATBITS` definition. Use the matching `boot12.asm`, `boot16.asm`, or `boot32.asm` wrapper first, or wait for the build scripts to be synchronized.

## Development Rules

- Keep boot sectors at or below 512 bytes and preserve the trailing `0xAA55` signature.
- Keep 8086-compatible paths within the 8086 instruction set; place code requiring 32-bit registers only in stages that explicitly allow it.
- After changing boot, kernel, or filesystem code, run at least one FASM build and a size check.
- When adding an external program, commit `programs/<name>.asm`; the build scripts generate the matching `.COM` file.
- Record design constraints in `docs/` and release changes in `CHANGELOG.md`.

## Contributing

Before submitting a change, describe the boot stage or system module affected, the verification command, and any known limitations. Changes involving disks, boot sectors, or filesystems should include reproducible test steps.

## License

This project is released under the GNU GPL v3 or later. See [LICENSE](LICENSE).

Copyright © 2026 Nexsteaduser. All Rights Reserved
