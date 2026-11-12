//! Turning the machine off, by QEMU's test device (`sifive_test`), which
//! ends QEMU with an exit status.

use core::volatile::Volatile;

use crate::board;

/// What to write to turn the machine off as one whose program worked, or
/// failed (with the exit status in the upper half).
const PASS: u32 = 0x5555;
const FAIL: u32 = 0x3333;

fn device() -> &'static Volatile<u32> {
    // SAFETY: the test device's register is a `u32` at `board::TEST`, and
    // only this module writes it.
    unsafe { Volatile::at(board::TEST) }
}

/// Turns the machine off, as one whose program worked: QEMU exits with 0.
pub fn off() -> ! {
    loop { device().write(PASS) }
}

/// Turns the machine off, as one whose program failed: QEMU exits with
/// `status`.
pub fn fail(status: { s: u32 | s > 0 && s < 0x1_0000 }) -> ! {
    loop { device().write((status << 16) | FAIL) }
}
