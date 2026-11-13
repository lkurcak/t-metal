//! Traps: where the machine goes when an interrupt comes, or when an
//! instruction can't be run. start.S's `trap_vector` calls `trap`.

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
        core::panic::panic_with(&f"trap: cause 0x{cause:016x} at 0x{at:016x}");
    }
}

#[test]
fn a_cause_is_sixteen_digits() with {alloc, panic} {
    let s = alloc::string::String::of(&f"0x{TIMER:016x}");
    assert_eq(&s.as_str(), &"0x8000000000000007");
}
