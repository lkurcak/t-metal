//! t-metal: a T program on bare metal, a riscv64 machine with no operating
//! system (QEMU's `virt`). It's the only program on the machine: start.S
//! runs its `main` in machine mode, and it drives the devices itself,
//! through their registers: the serial port, the timer and its interrupt,
//! and the test device that turns the machine off. It reads lines typed at
//! the serial port, and runs each as a command of the shell (the `shell`
//! package, which runs on the hosted target too, for its tests).
//!
//! Nothing in it panics but what's asked to: `implicit_panics` warns of
//! any arithmetic, or index, the checker can't prove is in range, and CI
//! denies warnings.
#![warn(implicit_panics)]

use alloc::list::List;
use shell::{Outcome, Shell};

use board::Board;
use uart::Uart;

mod board;
mod heap;
mod power;
mod timer;
mod trap;
mod uart;

fn main() {
    timer::start();
    let mut uart = Uart {};
    let mut shell = Shell::new();
    shell.start(&mut uart).into_ok();
    loop {
        match shell.feed(uart::get(), &Board {}, &mut uart).into_ok() {
            Outcome::Read => {},
            Outcome::Halt => return,
            Outcome::Panic => core::panic::panic("asked to"),
            Outcome::Exhaust => exhaust(),
            // SAFETY: `breakpoint` is start.S's, and only runs `ebreak`,
            // whose trap `trap` takes, and panics.
            Outcome::Trap => unsafe { breakpoint() },
        }
    }
}

/// Allocates blocks, keeping each, until the heap runs out: `alloc`'s
/// abort, which stops the machine.
fn exhaust() -> ! {
    let mut blocks = List::new();
    loop {
        blocks.push(List::<u8>::with_capacity(64 * 1024));
    }
}

// C's side: what start.S and platform.c call, and what T calls of
// theirs. They're all here, in the program's root module, as an `extern
// fn` in a module gets a C name with the module's path in it, which isn't
// C (FRICTION.md).

/// Writes a byte of a panic's message, to the serial port: the platform's
/// (docs/39-freestanding.md and docs/40-extern.md of t-lang).
extern fn t_platform_write(b: u8) { uart::put_text(b) }

/// Stops the machine after a panic: QEMU exits with 1. The platform's.
extern fn t_platform_halt() -> ! { power::fail(1) }

/// Turns the machine off once `main` gives back: QEMU exits with 0.
/// start.S calls it.
extern fn poweroff() -> ! { power::off() }

/// Takes a trap, of cause `cause` (`mcause`), which came at the instruction
/// at `at` (`mepc`); start.S's `trap_vector` calls it. It runs between two
/// instructions of the program, any two once interrupts are in, so it
/// shares nothing with the program but statics; and it mustn't allocate,
/// as it may have come in the middle of an allocation.
extern fn trap(cause: u64, at: u64) with {global, panic} { trap::take(cause, at) }

/// Lets the timer's interrupt in: start.S's.
extern fn enable_interrupts();

/// Runs `ebreak`, whose trap, a breakpoint, `trap` doesn't expect: so it
/// never gives back. start.S's.
extern fn breakpoint() -> !;

/// How the heap is doing: platform.c's.
extern fn heap_size() -> usize with global;
extern fn heap_touched() -> usize with global;
extern fn heap_used() -> usize with global;
extern fn heap_peak() -> usize with global;
extern fn heap_live() -> usize with global;
