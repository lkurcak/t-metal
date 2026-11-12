//! QEMU's `virt` machine, as t-metal uses it: where its devices are (its
//! device tree says so; these are where QEMU puts them), and the board as
//! the shell sees it.

use shell::{Machine, Memory};

use crate::{heap, timer};

/// The serial port, a 16550 UART: its eight byte-wide registers.
pub const UART: usize = 0x1000_0000;
/// The test device (`sifive_test`), which turns the machine off.
pub const TEST: usize = 0x10_0000;
/// The CLINT's `mtimecmp` of hart 0: the timer interrupts once `mtime`
/// reaches it.
pub const MTIMECMP: usize = 0x200_4000;
/// The CLINT's `mtime`, which counts up from when the machine starts.
pub const MTIME: usize = 0x200_BFF8;
/// How fast `mtime` counts, a second's worth.
pub const TIMEBASE_HZ: u64 = 10_000_000;

/// The board, for the shell to ask about.
#[derive(Copy, Discard)]
pub struct Board {}

impl Machine for Board {
    effect e = global;

    fn uptime_ms(&self) -> u64 with global { timer::uptime_ms() }

    fn ticks(&self) -> u64 with global { timer::ticks() }

    fn sleep(&self, ms: u64) with global { timer::sleep(ms) }

    fn memory(&self) -> Memory with global { heap::memory() }
}
