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
            Outcome::Trap => unsafe { trap::breakpoint() },
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
