//! The commands: what a line asks for, read from its words.

use core::fmt::{Display, Write};

use crate::primes::MOST;

/// What `help` writes.
pub const HELP: &str = "commands:
  help           this
  echo TEXT      writes TEXT back
  uptime         how long since the machine started, and its timer interrupts
  sleep MS       waits MS milliseconds, on the timer
  mem            how the heap is doing
  set KEY VALUE  gives KEY the value VALUE
  get KEY        KEY's value
  del KEY        forgets KEY
  keys           every KEY with a value, in order
  primes N       the primes up to N, at most 1000000
  panic          panics, which stops the machine
  exhaust        allocates until the heap runs out, which stops the machine
  trap           runs an instruction that traps, which stops the machine
  halt           turns the machine off
";

/// How `primes` is used.
const PRIMES: &str = "primes N, a whole number up to 1000000";

/// A line, read as a command.
#[derive(Copy, Discard)]
pub enum Command<'a> {
    /// Nothing, or only spaces.
    Nothing,
    Help,
    Echo(&'a str),
    Uptime,
    Sleep(u64),
    Mem,
    Set(&'a str, &'a str),
    Get(&'a str),
    Del(&'a str),
    Keys,
    Primes({ n: usize | n <= MOST }),
    Panic,
    Exhaust,
    Trap,
    Halt,
}

/// What's wrong with a line, or with what it asks for.
#[derive(Copy, Discard)]
pub enum Wrong<'a> {
    /// Its first word is no command.
    Unknown(&'a str),
    /// The rest of it isn't what its command takes: the command's usage.
    Usage(&'a str),
    /// A key with no value.
    NoKey(&'a str),
}

impl<'a> Display for Wrong<'a> {
    fn fmt<W: Write>(&self, w: &mut W) -> Result<(), W::Error> with W::e {
        match *self {
            Wrong::Unknown(name) => w.put(&f"no command `{name}`: `help` lists them"),
            Wrong::Usage(usage) => w.put(&f"usage: {usage}"),
            Wrong::NoKey(key) => w.put(&f"no value for {key}"),
        }
    }
}

/// Reads `line` as a command.
pub fn parse<'a>(line: &'a str) -> Result<Command<'a>, Wrong<'a>> {
    let line = line.trim();
    let mut words = line.split_whitespace();
    let Some(name) = words.next() else { return Ok(Command::Nothing) };
    // What's after the command's name, as typed.
    let rest = match line.strip_prefix(name) {
        Some(rest) => rest.trim_start(),
        None => "",
    };
    // The commands that take nothing after their name.
    let bare = match name {
        "help" => Some(Command::Help),
        "uptime" => Some(Command::Uptime),
        "mem" => Some(Command::Mem),
        "keys" => Some(Command::Keys),
        "panic" => Some(Command::Panic),
        "exhaust" => Some(Command::Exhaust),
        "trap" => Some(Command::Trap),
        "halt" => Some(Command::Halt),
        _ => None,
    };
    if let Some(c) = bare {
        return if rest.is_empty() { Ok(c) } else { Err(Wrong::Usage(name)) };
    }
    match name {
        "echo" => Ok(Command::Echo(rest)),
        "sleep" => match rest.parse::<u64>() {
            Ok(ms) => Ok(Command::Sleep(ms)),
            Err(_) => Err(Wrong::Usage("sleep MS, a whole number of milliseconds")),
        },
        "set" => {
            let mut words = rest.split_whitespace();
            let Some(key) = words.next() else { return Err(Wrong::Usage("set KEY VALUE")) };
            let value = match rest.strip_prefix(key) {
                Some(value) => value.trim_start(),
                None => "",
            };
            if value.is_empty() {
                return Err(Wrong::Usage("set KEY VALUE"));
            }
            Ok(Command::Set(key, value))
        },
        "get" => match one_word(rest) {
            Some(key) => Ok(Command::Get(key)),
            None => Err(Wrong::Usage("get KEY")),
        },
        "del" => match one_word(rest) {
            Some(key) => Ok(Command::Del(key)),
            None => Err(Wrong::Usage("del KEY")),
        },
        "primes" => match rest.parse::<usize>() {
            Ok(n) => if n <= MOST { Ok(Command::Primes(n)) } else { Err(Wrong::Usage(PRIMES)) },
            Err(_) => Err(Wrong::Usage(PRIMES)),
        },
        _ => Err(Wrong::Unknown(name)),
    }
}

/// `s`, if it's one word.
fn one_word(s: &str) -> Option<&str> {
    let mut words = s.split_whitespace();
    let word = words.next()?;
    match words.next() {
        Some(_) => None,
        None => Some(word),
    }
}
