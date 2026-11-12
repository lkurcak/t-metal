/* Where t-metal goes in QEMU's `virt` machine: its RAM starts at
 * 0x8000_0000, which is where the machine jumps with `-bios none`. The
 * program, then its zeroed data, then the heap `platform.c` hands out, then
 * the stack, which grows down from `_stack_top`. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

HEAP_SIZE = 4M;
STACK_SIZE = 256K;

SECTIONS {
    . = 0x80000000;
    .text : { KEEP(*(.text.start)) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.* .srodata .srodata.*) }
    .data : { *(.data .data.* .sdata .sdata.*) }

    . = ALIGN(16);
    _bss_start = .;
    .bss : { *(.sbss .sbss.* .bss .bss.* COMMON) }
    . = ALIGN(16);
    _bss_end = .;

    _heap_start = .;
    . = . + HEAP_SIZE;
    _heap_end = .;

    . = ALIGN(16);
    . = . + STACK_SIZE;
    _stack_top = .;
}
