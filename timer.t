//! The machine's timer: the CLINT's `mtime`, counting at
//! `board::TIMEBASE_HZ` from when the machine starts, and an interrupt
//! `HZ` times a second, which `TICKS` counts.

use core::num::{saturating_add, wrapping_add};
use core::sync::Atomic;
use core::volatile::Volatile;

use crate::{board, enable_interrupts};

/// How many times a second the timer interrupts.
const HZ: u64 = 100;
/// How far `mtime` counts between two interrupts.
const PERIOD: u64 = board::TIMEBASE_HZ / HZ;

/// The timer interrupts taken. An interrupt can come between any two
/// instructions of the program, so what it changes is a static, and an
/// atomic one.
static TICKS: Atomic<u64> = Atomic::new(0);

fn mtime() -> &'static Volatile<u64> {
    // SAFETY: the CLINT's `mtime` is at `board::MTIME`; the program only
    // reads it.
    unsafe { Volatile::at(board::MTIME) }
}

fn mtimecmp() -> &'static Volatile<u64> {
    // SAFETY: hart 0's `mtimecmp` is at `board::MTIMECMP`, and only this
    // module reads or writes it.
    unsafe { Volatile::at(board::MTIMECMP) }
}

/// Starts the timer's interrupts.
pub fn start() {
    mtimecmp().write(wrapping_add(mtime().read(), PERIOD));
    // SAFETY: `enable_interrupts` is start.S's, and only sets two bits of
    // two machine registers. `trap` is ready for the interrupt.
    unsafe { enable_interrupts() }
}

/// Takes a timer interrupt: counts it, and asks for the next one a
/// `PERIOD` after it was due, so the ticks don't drift.
pub fn interrupt() with global {
    let _ = TICKS.fetch_add(1);
    mtimecmp().write(wrapping_add(mtimecmp().read(), PERIOD));
}

/// The timer interrupts taken since `start`.
pub fn ticks() -> u64 with global { TICKS.load() }

/// Milliseconds since the machine started.
pub fn uptime_ms() -> u64 { mtime().read() / (board::TIMEBASE_HZ / 1000) }

/// Waits until at least `ms` milliseconds have gone by, counted in the
/// timer's interrupts.
pub fn sleep(ms: u64) with global {
    // Whole ticks, rounded up, and one more: the tick that's under way
    // has gone by in part.
    let wait = ms / (1000 / HZ) + if ms % (1000 / HZ) == 0 { 1 } else { 2 };
    let until = saturating_add(ticks(), wait);
    while ticks() < until {}
}
