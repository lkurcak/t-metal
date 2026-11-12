//! The serial port: a 16550 UART, which is where the shell reads what's
//! typed and writes what it says, and where a panic's message goes.

use core::fmt::Write;
use core::volatile::Volatile;

use crate::board;

/// Its registers, by offset: the byte received (read) or to send
/// (written), and the line's status.
const DATA: usize = 0;
const STATUS: usize = 5;
/// Status bits: a byte has been received; there's room for one to send.
const RECEIVED: u8 = 0x01;
const ROOM: u8 = 0x20;

/// Register `offset` of the UART.
fn register(offset: { o: usize | o < 8 }) -> &'static Volatile<u8> {
    // SAFETY: the UART's registers are bytes at `board::UART` and the
    // seven after it, and only this module reads or writes them.
    unsafe { Volatile::at(board::UART + offset) }
}

/// Sends byte `b`, once there's room for it.
pub fn put(b: u8) {
    while register(STATUS).read() & ROOM == 0 {}
    register(DATA).write(b)
}

/// Waits for a byte to be received, and gives it.
pub fn get() -> u8 {
    while register(STATUS).read() & RECEIVED == 0 {}
    register(DATA).read()
}

/// Sends byte `b` of text: a line break as a carriage return and a line
/// feed, as a terminal wants it.
pub fn put_text(b: u8) {
    if b == b'\n' {
        put(b'\r');
    }
    put(b)
}

/// Writes a byte of a panic's message, to the serial port: the platform's
/// (docs/39-freestanding.md and docs/40-extern.md of t-lang).
extern fn t_platform_write(b: u8) { put_text(b) }

/// The serial port, as somewhere to write text. Writing to it can't fail.
#[derive(Discard)]
pub struct Uart {}

impl Write for Uart {
    type Error = !;
    effect e = {};

    fn write_str(&mut self, s: &str) -> Result<(), !> {
        for b in s.as_bytes().iter() {
            put_text(*b);
        }
        Ok(())
    }

    fn write_char(&mut self, c: char) -> Result<(), !> {
        let mut bytes = [0u8; 4];
        match c.encode_utf8(bytes.as_mut_slice()) {
            Some(s) => self.write_str(s),
            None => Ok(()),
        }
    }
}
