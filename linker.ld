ENTRY(start)

SECTIONS {
    . = 1M;

    .boot :
    {
        *(.multiboot)
        *(.boot)
    }

    .text :
    {
        *(.text*)
    }

    .rodata :
    {
        *(.rodata*)
    }

    .data :
    {
        *(.data*)
    }

    .bss :
    {
        *(.bss*)
        *(COMMON)
    }

    . = ALIGN(16);
    _stack_bottom = .;
    . += 64K;
    _stack_top = .;

    /DISCARD/ :
    {
        *(.comment*)
        *(.eh_frame*)
        *(.note.gnu.build-id*)
    }
}
