//! The shell's tests: what it writes back when something is typed at it,
//! on a machine whose clock moves only when it sleeps.

use alloc::string::String;
use core::cell::Cell;
use core::num::saturating_add;

use crate::{Machine, Memory, Outcome, Shell};

/// What the shell says first.
const HELLO: &str = "t-metal: T on bare metal. Type `help` for the commands.\n> ";

/// A machine whose clock moves only when it sleeps, with a heap that
/// always looks the same.
#[derive(Discard)]
struct Fake { now: Cell<u64> }

impl Machine for Fake {
    effect e = {};

    fn uptime_ms(&self) -> u64 { self.now.get() }

    fn ticks(&self) -> u64 { self.now.get() / 10 }

    fn sleep(&self, ms: u64) { self.now.set(saturating_add(self.now.get(), ms)) }

    fn memory(&self) -> Memory {
        Memory { size: 4096, touched: 160, used: 72, peak: 100, blocks: 3 }
    }
}

/// What the shell writes when `typed` is typed at it, after its hello, and
/// what it leaves to the kernel after the last byte.
fn session(typed: &str) -> (String, Outcome) {
    let mut shell = Shell::new();
    let mut out = String::new();
    let machine = Fake { now: Cell::new(0) };
    shell.start(&mut out).into_ok();
    out.clear();
    let mut last = Outcome::Read;
    for b in typed.as_bytes() {
        last = shell.feed(*b, &machine, &mut out).into_ok();
    }
    (out, last)
}

/// That `typed` makes the shell write `written`, and then wait for more.
fn writes(typed: &str, written: &str) {
    let (out, last) = session(typed);
    assert_eq(out.as_str(), written);
    assert(match last {
        Outcome::Read => true,
        _ => false,
    });
}

/// That typing each step's first string, one after another, makes the
/// shell write its second, and then wait for more.
fn steps(steps: &[(&str, &str)]) {
    let mut typed = String::new();
    let mut written = String::new();
    for step in steps {
        typed.push_str(step.0);
        written.push_str(step.1);
    }
    writes(typed.as_str(), written.as_str())
}

#[test]
fn says_hello() {
    let mut out = String::new();
    Shell::new().start(&mut out).into_ok();
    assert_eq(out.as_str(), HELLO);
}

#[test]
fn echoes() {
    writes("echo  hello,  world \n", "echo  hello,  world \nhello,  world\n> ");
    writes("echo\n", "echo\n\n> ");
    writes("\n   \n", "\n>    \n> ");
}

#[test]
fn enter_is_a_return_a_feed_or_both() {
    writes("echo a\recho b\r\necho c\n", "echo a\na\n> echo b\nb\n> echo c\nc\n> ");
    // A feed after a feed is an empty line; after a return, it's not.
    writes("\n\n\r\n", "\n> \n> \n> ");
}

#[test]
fn edits() {
    // Backspace and delete rub out a character, Ctrl-U the whole line.
    writes("ecjo\u{8}\u{8}ho hi\u{7f}!\n", "ecjo\u{8} \u{8}\u{8} \u{8}ho hi\u{8} \u{8}!\nh!\n> ");
    writes("\u{8}x\u{15}echo y\n", "x\u{8} \u{8}echo y\ny\n> ");
    // Ctrl-C drops the line.
    writes("echo no\u{3}echo yes\n", "echo no^C\n> echo yes\nyes\n> ");
    // Arrow keys and other escape sequences are left out, as is what isn't ASCII.
    writes("ec\u{1b}[Aho\u{1b}[1;5D ét\n", "echo t\nt\n> ");
}

#[test]
fn says_what_is_wrong() {
    writes("frob 3\n", "frob 3\nno command `frob`: `help` lists them\n> ");
    writes("sleep x\n", "sleep x\nusage: sleep MS, a whole number of milliseconds\n> ");
    writes("get\n", "get\nusage: get KEY\n> ");
    writes("get a b\n", "get a b\nusage: get KEY\n> ");
    writes("set a\n", "set a\nusage: set KEY VALUE\n> ");
    writes("halt now\n", "halt now\nusage: halt\n> ");
}

#[test]
fn keeps_values() {
    steps(
        &[
            ("set b two words\n", "set b two words\nb = two words\n> "),
            ("set a 1\n", "set a 1\na = 1\n> "),
            ("get b\n", "get b\ntwo words\n> "),
            ("set a one\n", "set a one\na = one (was 1)\n> "),
            ("keys\n", "keys\na\nb\n> "),
            ("del a\n", "del a\nforgot a = one\n> "),
            ("get a\n", "get a\nno value for a\n> "),
            ("del a\n", "del a\nno value for a\n> "),
            ("keys\n", "keys\nb\n> "),
        ],
    );
    writes("keys\n", "keys\nno keys\n> ");
}

#[test]
fn asks_the_machine() {
    writes(
        "uptime\nsleep 25\nuptime\n",
        "uptime\nup 0 ms, 0 timer interrupts\n> sleep 25\n> uptime\nup 25 ms, 2 timer interrupts\n> ",
    );
    writes(
        "mem\n",
        "mem\nheap: 72 bytes in 3 blocks, at most 100\n      160 of 4096 bytes ever given out\n> ",
    );
}

#[test]
fn finds_primes() {
    writes("primes 1\n", "primes 1\nno primes up to 1\n> ");
    writes(
        "primes 30\n",
        "primes 30\n2 3 5 7 11 13 17 19 23 29\n10 primes up to 30, the largest 29\n> ",
    );
    writes("primes 1000\n", "primes 1000\n168 primes up to 1000, the largest 997\n> ");
}

#[test]
fn leaves_the_machine_to_the_kernel() {
    let (out, last) = session("echo a\nhalt\n");
    assert_eq(out.as_str(), "echo a\na\n> halt\n");
    assert(match last {
        Outcome::Halt => true,
        _ => false,
    });
    assert(match session("panic\n").1 {
        Outcome::Panic => true,
        _ => false,
    });
    assert(match session("exhaust\n").1 {
        Outcome::Exhaust => true,
        _ => false,
    });
    assert(match session("trap\n").1 {
        Outcome::Trap => true,
        _ => false,
    });
}
