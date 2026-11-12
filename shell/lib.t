//! t-metal's shell: what it does with the bytes typed at it. It edits a
//! line as it's typed, and runs it as a command once it ends. It touches
//! no machine, only the `Machine` it's given and the sink it writes to, so
//! it runs on the hosted target too, where its tests run; the kernel
//! (`main.t`) gives it the board, and the UART to write to.
//!
//! Nothing in it panics: `implicit_panics` warns of any arithmetic, or
//! index, the checker can't prove is in range, and CI denies warnings.
#![warn(implicit_panics)]

use alloc::list::List;
use alloc::string::String;
use core::fmt::Write;
use hashmap::Map;

use command::{Command, Wrong};
use line::Editor;

mod command;
mod line;
mod primes;
mod tests;

/// What the shell needs of the machine it runs on.
export trait Machine {
    /// What asking the machine may do.
    effect e;

    /// Milliseconds since the machine started.
    fn uptime_ms(&self) -> u64 with Self::e;

    /// Timer interrupts the machine has taken since it started.
    fn ticks(&self) -> u64 with Self::e;

    /// Waits until `ms` milliseconds have gone by.
    fn sleep(&self, ms: u64) with Self::e;

    /// How the machine's heap is doing.
    fn memory(&self) -> Memory with Self::e;
}

/// How a heap is doing, in bytes, and in blocks given out.
#[derive(Copy, Discard)]
export struct Memory {
    /// How big it is.
    export size: usize,
    /// How much of it has ever been given out.
    export touched: usize,
    /// How many bytes the blocks given out and not back hold.
    export used: usize,
    /// The most `used` has ever been.
    export peak: usize,
    /// How many blocks are given out and not back.
    export blocks: usize,
}

/// What's left for the kernel to do after a line: read the next, or what
/// only it can do.
#[derive(Copy, Discard)]
export enum Outcome {
    /// Read the next byte.
    Read,
    /// Turn the machine off.
    Halt,
    /// Panic.
    Panic,
    /// Allocate until the heap runs out.
    Exhaust,
    /// Run an instruction that traps.
    Trap,
}

/// The shell: the line being typed, and the keys `set` has given values.
#[derive(Discard)]
export struct Shell { editor: Editor, values: Map<String, String> }

impl Shell {
    /// A shell with nothing typed and no values.
    export fn new() -> Shell { Shell { editor: Editor::new(), values: Map::new() } }

    /// Says hello, and asks for the first line.
    export fn start<W: Write>(&mut self, out: &mut W) -> Result<(), W::Error> with W::e {
        out.write_str("t-metal: T on bare metal. Type `help` for the commands.\n")?;
        out.write_str("> ")
    }

    /// Takes byte `b`, typed. Once it ends a line, runs the line, writing
    /// what it says to `out`, and then asks for the next.
    export fn feed<M: Machine, W: Write>(
        &mut self,
        b: u8,
        machine: &M,
        out: &mut W,
    ) -> Result<Outcome, W::Error> with {alloc, M::e, W::e} {
        let Some(line) = self.editor.feed(b, out)? else { return Ok(Outcome::Read) };
        let outcome = match command::parse(line.as_str()) {
            Ok(c) => self.run(c, machine, out)?,
            Err(wrong) => {
                out.line(&wrong)?;
                Outcome::Read
            },
        };
        if let Outcome::Read = outcome {
            out.write_str("> ")?;
        }
        Ok(outcome)
    }

    /// Runs command `c`.
    fn run<M: Machine, W: Write>(
        &mut self,
        c: Command,
        machine: &M,
        out: &mut W,
    ) -> Result<Outcome, W::Error> {
        match c {
            Command::Nothing => {},
            Command::Help => out.write_str(command::HELP)?,
            Command::Echo(text) => out.line(text)?,
            Command::Uptime => {
                let ms = machine.uptime_ms();
                let ticks = machine.ticks();
                out.line(&f"up {ms} ms, {ticks} timer interrupts")?
            },
            Command::Sleep(ms) => machine.sleep(ms),
            Command::Mem => {
                let m = machine.memory();
                out.line(&f"heap: {m.used} bytes in {m.blocks} blocks, at most {m.peak}")?;
                out.line(&f"      {m.touched} of {m.size} bytes ever given out")?
            },
            Command::Set(key, value) => {
                let old = self.values.insert(String::from(key), String::from(value));
                match old {
                    Some(old) => out.line(&f"{key} = {value} (was {old})")?,
                    None => out.line(&f"{key} = {value}")?,
                }
            },
            Command::Get(key) => match self.values.get(key) {
                Some(value) => out.line(value)?,
                None => out.line(&Wrong::NoKey(key))?,
            },
            Command::Del(key) => match self.values.remove(key) {
                Some(value) => out.line(&f"forgot {key} = {value}")?,
                None => out.line(&Wrong::NoKey(key))?,
            },
            Command::Keys => self.keys(out)?,
            Command::Primes(n) => primes::write(n, out)?,
            Command::Panic => return Ok(Outcome::Panic),
            Command::Exhaust => return Ok(Outcome::Exhaust),
            Command::Trap => return Ok(Outcome::Trap),
            Command::Halt => return Ok(Outcome::Halt),
        }
        Ok(Outcome::Read)
    }

    /// Writes every key `set` has given a value, in order.
    fn keys<W: Write>(&self, out: &mut W) -> Result<(), W::Error> {
        if self.values.is_empty() {
            return out.line("no keys");
        }
        let mut keys = List::new();
        for (key, _) in self.values.iter() {
            keys.push(key);
        }
        for key in heap::Heap::from_list(keys).into_sorted().iter() {
            out.line(*key)?;
        }
        Ok(())
    }
}
