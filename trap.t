//! Traps: where the machine goes when an interrupt comes, or when an
//! instruction can't be run. start.S's `trap_vector` calls `trap`.

use core::fmt::{Display, Write};

use crate::timer;

/// `mcause` of the machine timer's interrupt: the interrupt bit, and 7.
const TIMER: u64 = 0x8000_0000_0000_0007;

/// Takes the trap of cause `cause` (`mcause`), which came at the
/// instruction at `at` (`mepc`). A trap that isn't the timer's is a fault
/// of the program's, which can't go on.
pub fn take(cause: u64, at: u64) with {global, panic} {
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
