.PHONY: all clean build kernel bootloader iso run

all: iso

clean:
    cargo clean
    rm -rf iso/*.iso iso/boot

build: kernel bootloader

kernel:
    cd kernel && cargo build --release

bootloader:
    cd bootloader && cargo build --release

iso: build
    @echo "Creating ISO image..."
    @mkdir -p iso/boot/grub
    @cp bootloader/target/x86_64-nexsteaduser-os/release/bootloader.bin iso/boot/bootloader.bin
    @cp kernel/target/x86_64-nexsteaduser-os/release/nexsteaduser-kernel.bin iso/boot/kernel.bin
    @echo "set timeout=0" > iso/boot/grub/grub.cfg
    @echo "set default=0" >> iso/boot/grub/grub.cfg
    @echo "" >> iso/boot/grub/grub.cfg
    @echo "menuentry 'Nexsteaduser OS' {" >> iso/boot/grub/grub.cfg
    @echo "    multiboot /boot/bootloader.bin" >> iso/boot/grub/grub.cfg
    @echo "    module /boot/kernel.bin" >> iso/boot/grub/grub.cfg
    @echo "    boot" >> iso/boot/grub/grub.cfg
    @echo "}" >> iso/boot/grub/grub.cfg
    @grub-mkrescue -o nexsteaduser-os.iso iso

run: iso
    @qemu-system-x86_64 -cdrom nexsteaduser-os.iso -m 512M -serial stdio

debug: iso
    @qemu-system-x86_64 -cdrom nexsteaduser-os.iso -m 512M -serial stdio -s -S

test:
    @echo "Running tests..."
    @cd kernel && cargo test
