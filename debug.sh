#!/bin/bash

echo "Debugging Nexsteaduser OS in QEMU..."
qemu-system-x86_64 -cdrom nexsteaduser-os.iso -m 512M -serial stdio -s -S
echo "GDB server listening on :1234"
echo "Connect with: gdb kernel/target/x86_64-nexsteaduser-os/release/nexsteaduser-kernel.bin"
