//! How the heap is doing, as `platform.c`, which hands it out, counts.

use shell::Memory;

use crate::{heap_live, heap_peak, heap_size, heap_touched, heap_used};

/// How the heap is doing now.
pub fn memory() -> Memory with global {
    // SAFETY: these are platform.c's, which only read its counters. Only
    // `main` allocates, so the counters don't change while they're read.
    unsafe {
        Memory {
            size: heap_size(),
            touched: heap_touched(),
            used: heap_used(),
            peak: heap_peak(),
            blocks: heap_live(),
        }
    }
}
