//! How the heap is doing, as `platform.c`, which hands it out, counts.

use shell::Memory;

/// What platform.c counts of the heap: its size, how much of it was ever
/// handed out, how much is now and at most, and how many blocks are.
extern fn heap_size() -> usize with global;
extern fn heap_touched() -> usize with global;
extern fn heap_used() -> usize with global;
extern fn heap_peak() -> usize with global;
extern fn heap_live() -> usize with global;

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
