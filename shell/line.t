//! A line as it's typed at a terminal, a byte at a time, echoed back.

use alloc::string::String;
use core::fmt::Write;
use core::mem::replace;

/// Backspace, and what most terminals send for it.
const BACKSPACE: u8 = 0x08;
const DELETE: u8 = 0x7f;
/// Ctrl-C: drops the line.
const CANCEL: u8 = 0x03;
/// Ctrl-U: rubs out the line, to type it again.
const KILL: u8 = 0x15;
/// What starts a key's escape sequence, as an arrow key's.
const ESCAPE: u8 = 0x1b;

/// Where the editor is in what's typed.
#[derive(Copy, Discard)]
enum State {
    /// Within a line.
    Typing,
    /// Just after a carriage return, which ended a line: a line feed
    /// next is part of the same Enter, not an empty line.
    AfterReturn,
    /// After an escape: a `[` next starts a control sequence.
    Escape,
    /// Within a control sequence, which a byte from `@` to `~` ends.
    Sequence,
}

/// A line being typed: printable ASCII, edited with backspace, Ctrl-U and
/// Ctrl-C; Enter (a carriage return, a line feed, or both) ends it. Keys
/// that send escape sequences, as the arrows do, and bytes outside ASCII
/// are left out.
#[derive(Discard)]
pub struct Editor { line: String, state: State }

impl Editor {
    /// An editor with nothing typed.
    pub fn new() -> Editor { Editor { line: String::new(), state: State::Typing } }

    /// Takes byte `b`, echoing to `out` what it does to the line. Gives the
    /// line once `b` ends it.
    pub fn feed<W: Write>(&mut self, b: u8, out: &mut W) -> Result<Option<String>, W::Error>
    with {alloc, W::e}
    {
        let state = self.state;
        self.state = State::Typing;
        match state {
            State::Escape => {
                if b == b'[' {
                    self.state = State::Sequence;
                }
                return Ok(None);
            },
            State::Sequence => {
                if b < 0x40 || b > 0x7e {
                    self.state = State::Sequence;
                }
                return Ok(None);
            },
            State::AfterReturn => {
                if b == b'\n' {
                    return Ok(None);
                }
            },
            State::Typing => {},
        }
        if b == b'\r' || b == b'\n' {
            if b == b'\r' {
                self.state = State::AfterReturn;
            }
            out.write_char('\n')?;
            return Ok(Some(replace(&mut self.line, String::new())));
        }
        if b == BACKSPACE || b == DELETE {
            if self.line.pop().is_some() {
                out.write_str("\x08 \x08")?;
            }
        } else if b == KILL {
            while self.line.pop().is_some() {
                out.write_str("\x08 \x08")?;
            }
        } else if b == CANCEL {
            self.line.clear();
            out.write_str("^C\n")?;
            return Ok(Some(String::new()));
        } else if b == ESCAPE {
            self.state = State::Escape;
        } else if b >= 0x20 && b < 0x7f {
            let c = b as char;
            self.line.push(c);
            out.write_char(c)?;
        }
        Ok(None)
    }
}
