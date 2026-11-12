/* t-metal's start-up code: what runs before T's `main` and around each
 * trap. The machine starts every hart here, in machine mode, with nothing
 * set up. Hart 0 makes a stack, zeroes the program's zeroed data, points
 * traps at `trap_vector` and runs T's `main` (`t_main`); when it gives
 * back, T's `poweroff` turns the machine off. Any other hart waits for
 * ever. */

    .section .text.start, "ax"
    .globl _start
_start:
    csrr t0, mhartid
    bnez t0, park

    la sp, _stack_top

    la t0, _bss_start
    la t1, _bss_end
1:  bgeu t0, t1, 2f
    sd zero, 0(t0)
    addi t0, t0, 8
    j 1b

2:  la t0, trap_vector
    csrw mtvec, t0

    call t_main
    call poweroff

park:
    wfi
    j park

    .text

/* `extern fn enable_interrupts()`: lets the machine timer interrupt in. */
    .globl enable_interrupts
enable_interrupts:
    li t0, 0x80        /* mie.MTIE */
    csrs mie, t0
    csrsi mstatus, 0x8 /* mstatus.MIE */
    ret

/* `extern fn breakpoint() -> !`: a breakpoint trap, which T's `trap`
 * doesn't expect, so it never comes back here. */
    .globl breakpoint
breakpoint:
    ebreak
    j breakpoint

/* Every trap comes here (mtvec is in direct mode). It keeps the registers
 * a C call may change, calls T's `trap(mcause, mepc)`, and goes back to
 * where the trap came from. The registers a C call keeps, `trap` keeps. */
    .balign 4
trap_vector:
    addi sp, sp, -128
    sd ra, 0(sp)
    sd t0, 8(sp)
    sd t1, 16(sp)
    sd t2, 24(sp)
    sd a0, 32(sp)
    sd a1, 40(sp)
    sd a2, 48(sp)
    sd a3, 56(sp)
    sd a4, 64(sp)
    sd a5, 72(sp)
    sd a6, 80(sp)
    sd a7, 88(sp)
    sd t3, 96(sp)
    sd t4, 104(sp)
    sd t5, 112(sp)
    sd t6, 120(sp)

    csrr a0, mcause
    csrr a1, mepc
    call trap

    ld ra, 0(sp)
    ld t0, 8(sp)
    ld t1, 16(sp)
    ld t2, 24(sp)
    ld a0, 32(sp)
    ld a1, 40(sp)
    ld a2, 48(sp)
    ld a3, 56(sp)
    ld a4, 64(sp)
    ld a5, 72(sp)
    ld a6, 80(sp)
    ld a7, 88(sp)
    ld t3, 96(sp)
    ld t4, 104(sp)
    ld t5, 112(sp)
    ld t6, 120(sp)
    addi sp, sp, 128
    mret
