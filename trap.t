//! Traps: where the machine goes when an interrupt comes, or when an
//! instruction can't be run. start.S's `trap_vector` calls `trap`.

use core::fmt::{Display, Write};

use crate::timer;

/// `mcause` of the machine timer's interrupt: the interrupt bit, and 7.
const TIMER: u64 = 0x8000_0000_0000_0007;

/// Takes a trap, of cause `cause` (`mcause`), which came at the instruction
/// at `at` (`mepc`); start.S's `trap_vector` calls it. It runs between two
/// instructions of the program, any two once interrupts are in, so it
/// shares nothing with the program but statics; and, as an export, it
/// can't allocate, as it may have come in the middle of an allocation.
extern fn trap(cause: u64, at: u64) with {global, panic} { take(cause, at) }

/// Runs `ebreak`, whose trap, a breakpoint, `trap` doesn't expect: so it
/// never gives back. start.S's.
pub extern fn breakpoint() -> !;

/// Takes the trap of cause `cause` (`mcause`), which came at the
/// instruction at `at` (`mepc`). A trap that isn't the timer's is a fault
/// of the program's, which can't go on.
fn take(cause: u64, at: u64) with {global, panic} {
    if cause == TIMER {
        timer::interrupt();
    } else {
        core::panic::panic_with(&f"trap: cause {Hex { n: cause }} at {Hex { n: at }}");
    }
}

/// A number, written in hexadecimal.
#[derive(Copy, Discard)]
struct Hex { n: u64 }

impl Display for Hex {
    fn fmt<W: Write>(&self, w: &mut W) -> Result<(), W::Error> with W::e {
        w.write_str("0x")?;
        // Sixteen digits, the most significant first.
        for i in 0..16u32 {
            let digit = (self.n >> (60 - 4 * i)) & 0xf;
            let c = if digit < 10 { b'0' + digit as u8 } else { b'a' + (digit - 10) as u8 };
            w.write_char(c as char)?;
        }
        Ok(())
    }
}

#[test]
fn hex_is_sixteen_digits() with {alloc, panic} {
    let s = alloc::string::String::of(&Hex { n: 0x8000_0000_0000_0007 });
    assert_eq(&s.as_str(), &"0x8000000000000007");
}
