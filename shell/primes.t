//! The primes up to a number, by the sieve of Eratosthenes: a list of a
//! flag for each number, so the heap has something to do.

use alloc::list::List;
use core::fmt::Write;

/// How many primes `write` lists, at most; past that, it only counts them.
const LISTED: usize = 30;

/// The most `sieve` sieves up to: a flag for each number, a byte each,
/// is a megabyte of the heap.
pub const MOST: usize = 1_000_000;

/// Writes the primes up to `n`, and how many there are.
pub fn write<W: Write>(n: { n: usize | n <= MOST }, out: &mut W) -> Result<(), W::Error>
with {alloc, W::e}
{
    let found = sieve(n);
    if found.len() <= LISTED {
        let mut first = true;
        for p in found.iter() {
            if !first {
                out.write_char(' ')?;
            }
            first = false;
            out.put(p)?;
        }
        if !first {
            out.write_char('\n')?;
        }
    }
    match found.last() {
        Some(last) => out.line(&f"{found.len()} primes up to {n}, the largest {last}"),
        None => out.line(&f"no primes up to {n}"),
    }
}

/// The primes up to `n`, in order.
pub fn sieve(n: { n: usize | n <= MOST }) -> List<u32> with alloc {
    let mut found = List::new();
    // `composite[k]`: has a prime below `k` been found to divide it?
    let mut composite = List::filled(n + 1, false);
    let mut i: usize = 2;
    while i <= n invariant composite.len() == n + 1 {
        if !composite[i] {
            found.push(i as u32);
            let mut j = i + i;
            while j <= n invariant composite.len() == n + 1 && i <= n {
                composite[j] = true;
                j = j + i;
            }
        }
        i = i + 1;
    }
    found
}
