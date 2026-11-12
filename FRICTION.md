# Friction log

What got in the way of writing a bare-metal program in T, with the code
that hit it. Each entry is labelled:

- **gap**: T should have it;
- **by design**: T leaves it out on purpose, and the entry says what that
  costs here;
- **unsure**: not clear which;
- **works**: something that went better than expected.

The log is evidence for t-lang's plans, not a design for them.

Written against `t` 0.85.0. t-metal is the first program to use what
steps 38–41 added for machines with no operating system: the
freestanding target, `extern fn`, `Volatile`, statics and `Atomic`
(retrospective 8, N5). Entries say what 0.86.0 (t-lang step 71) and
0.87.0 (step 72) fixed.

## An `extern fn` in a module isn't C — gap

**Fixed in t 0.86.0**: an `extern fn` is C's by its own name wherever it's
declared. Each of t-metal's is in the module that does the work now:
`uart` writes the platform's bytes, `power` halts, `trap` takes traps,
`timer` lets interrupts in, `heap` reads platform.c's counters.

Any `extern fn` that isn't in the program's root module makes C the C
compiler rejects: its C name and its symbol both have the module's path in
them.

```rust
mod m {
    pub extern fn put(c: i32) -> i32;
}

fn main() {
    // SAFETY: any import will do.
    let _ = unsafe { m::put(104) };
}
```

```text
error: the C compiler `cc` failed:
main.c:884:13: error: expected '=', ',', ';', 'asm' or '__attribute__' before ':' token
...
```

For t-metal's `platform.t` the C was
`_Noreturn void x_platform::t_platform_halt(void) __asm__(T_SYMBOL("platform::t_platform_halt"));`.
Even with a C name that's C, the symbol would be wrong: docs/40 says an
`extern fn`'s C name is its own name, "one for the whole program", and
start.S calls `t_platform_halt`, not `platform::t_platform_halt`. It's
the same on the hosted target. No test of t-lang's puts an `extern fn` in a
module.

The checker already has it right: two `extern fn put`s in two modules are
refused, "a C name is one for the whole program". It's only the C backend:
`Gen::import_body` and `Gen::exports` (src/cgen.rs) take the item's path,
`d.name.name`, for its C name and its symbol. So a platform function in a
module isn't even seen as the platform's there (`PLATFORM_HOOKS` holds bare
names), and gets an `x_` name of its own.

So every `extern fn` of t-metal's is at the end of `main.t`, where each
export forwards to the module that does the work (`power::off`,
`trap::take`, `uart::put_text`), and each module calls the imports as
`crate::heap_used()`. The drivers' C would sit better beside them.

## `t check` can't check a program that writes the platform — gap

**Fixed in t 0.86.0**: a program that writes the platform is checked the
same for either target, and only running or building it hosted fails.
tests/run.sh runs `t check --deny-warnings main.t` and `t test
--deny-warnings main.t` (the kernel's first test, `trap`'s `Hex`), and
`t build` only makes the object.

docs/40 shows how to write `t_platform_write` and `t_platform_halt` in T,
and t-metal does. But a program that does can only be checked for the
freestanding target, and `t check`, `t test` and the language server only
check for the hosted one, where they're an error:

```text
$ t check main.t
type error: `t_platform_write` is the platform's, and on the hosted target the platform
            is the C library's: write it for the freestanding target
$ t check --target freestanding main.t
usage: t [run] <file.t> [args...]
...
```

So `t build --target freestanding` is the only check of the kernel. It has
no `--deny-warnings`, so tests/run.sh fails if it writes anything at all.
In an editor, `main.t` is always broken.

docs/39 made the target "a build flag, not a manifest field", so that "one
program can be built for both, and tested on the hosted one". That's true
of a program that leaves the platform to C, but not of one that writes it
in T, as docs/40 recommends: such a program is freestanding only. Either
`check`, `test` and the language server need `--target` (and the server
a way to know it), or a program could say in its `t.toml` which target
it's for after all.

What t-metal does instead is put everything that doesn't touch the
machine in a library, `shell`, which `t check` and `t test` check on the
hosted target. That's a good shape anyway, but the kernel's own modules
(`uart`, `timer`, `trap`, `power`, `board`) have no tests at all.

## An interrupt handler may allocate — unsure

**Fixed in t 0.86.0**: an export's effects, said or inferred, are at most
`global` and `panic`, so `trap`'s `with {global, panic}` is checked now.

start.S's trap vector calls the export `trap`, which may come between any
two instructions of `main`, including in the middle of the platform's
`t_platform_alloc`. Nothing stops an export from saying `with alloc`:

```rust
use alloc::list::List;

extern fn on_interrupt() with alloc {
    let mut l = List::new();
    l.push(1u8);
}
```

builds for the freestanding target. The platform's allocator, like most,
can't be called again while it runs, so a handler like that would break
the heap. t-metal's `trap` says `with {global, panic}` by hand, and its
comment says why; nothing checks it.

docs/40's argument for exports (E2) says an export called "from a callback
or an interrupt, shares with the code it interrupts only statics, which are
`Sync` and change only atomically". The heap is shared too, through
`alloc`. That's in docs/40's "interrupt handlers' own rules" row, missing
on purpose. The evidence here is that the rule an interrupt handler needs
is about effects: no `alloc` (and maybe no `panic` while a panic is being
written), which the checker could enforce if it knew which exports are
handlers.

## What an import that reads C's state should say — unsure

**Settled in t 0.86.0**: docs/40 says such an import says `with global`,
as t-metal's do.

platform.c counts the heap's bytes in C statics, and `heap_used()` gives
them to T. It isn't a function of its arguments: two calls can give
different results. t-metal's imports say `with global`, as reading a
static in T does, but docs/40 doesn't say what an import should declare
for reading (or writing) state that's C's. It doesn't matter to the
checker today, which never assumes two calls give the same thing, but
`global` is a promise about T's statics, and these aren't.

## `for` over a slice — unsure

docs/40's own example doesn't check:

```rust
fn put(s: &str) {
    for b in s.as_bytes() { uart().write(*b) }
}
```

```text
type error: `&[u8]` doesn't implement `Iterator`, which method `next` is of
```

It needs `s.as_bytes().iter()`. tests/docs.rs only parses and formats a
docs block with no `fn main`, so docs/40's example was never checked.
**Fixed in t 0.86.0**, the docs half: such blocks are checked, and
docs/40 says `.iter()`. Two
things: such blocks could be checked as items, and whether `for x in
slice` (and `in list`) should work at all is open; every `for` in t-metal
says `.iter()`.

## `%` in a loop invariant — gap

Writing a number in hexadecimal a digit at a time:

```rust
let mut shift: u32 = 64;
while shift > 0 invariant shift % 4 == 0 {
    shift = shift - 4;
    ...
}
```

```text
type error: an invariant can't use `%` yet: only `+`, `-` and `*` by a constant
```

Without the invariant, `shift - 4` may panic. `for i in 0..16u32` with
`60 - 4 * i` is what `trap.t` does instead, and it's as clear.

**Fixed in t 0.87.0**: a predicate, an invariant and a measure's body can
use `/` and `%` by a constant other than 0, meaning what they mean in a
body (t-lang docs/72-division.md). The loop above is proved: at its head,
`shift % 4 == 0` and `shift > 0` say `shift` is at least 4. `trap.t` keeps
its `for`.

## Small ones

- **No hexadecimal in `core::fmt`** (gap): a trap's cause and address are
  wanted in hex. `trap.t` has its own `Hex`. A `{x:x}` hole, or a `Hex`
  wrapper in `core::fmt`, would do.
- **No tuple structs** (by design, docs/58): `struct Hex { n: u64 }` and
  `Hex { n: cause }` where `Hex(cause)` was what came to mind.
- **`\x` only in byte literals** (unsure): backspace in a `&str` is
  `"\u{8} \u{8}"`, not `"\x08 \x08"`. `\x00` to `\x7f` are always one
  UTF-8 byte, which Rust allows in strings for that reason. **Fixed in t
  0.86.0**: `shell/line.t` says `"\x08 \x08"`.
- **No `&[a, b]` as a slice** (unsure): `steps(&[("a", "b"), ..])` is
  "expected `[(&str, &str)]`, found `[(&'static str, &'static str); 9]`";
  it's `[..].as_slice()`.
- **No `\` line continuation in string literals** (unsure): a test's
  expected output of nine commands was one long string, now a list of
  pairs.
- **`wrapping_add(a, b)`, not `a.wrapping_add(b)`** (by design?): `u64`
  has no method `wrapping_add`; the free function is `core::num`'s. The
  checker was right to ask: `mtime + PERIOD` may overflow, in principle.
- **No match guards** (by design, docs/02): `"help" if alone =>` became a
  `match` of the commands that take nothing, then the others.
- **`Volatile` can't be a static** (by design, docs/40: not `Sync`): each
  driver has a function per register that runs `unsafe { Volatile::at(..) }`
  with its `SAFETY` comment, which is fine.
- **clang's warnings on T's C** (small gap): when the C compile fails
  (as for the first entry), clang also writes hundreds of
  `-Wparentheses-equality` warnings for `if ((_1.tag == 0))`, which bury
  the error.

## What worked

- **The freestanding target, first try** (works): T to C with clang's
  riscv64 target (`CC=clang T_LANG_CFLAGS=--target=riscv64-unknown-elf ..`),
  linked with ld.lld and a 30-line linker script, ran on QEMU the first
  time: a hello, then a panic's message over the UART, and QEMU's exit
  status from the test device. `nm -u` of the object is exactly the
  platform's functions and t-metal's own imports.
- **An interrupt in T** (works): an export, called from a 40-line
  assembly trap vector, counts timer interrupts in a `static
  Atomic<u64>` that `main` reads. The checker asked for `wrapping_add` on
  the timer's compare register before it would build.
- **Libraries written for the hosted target, unchanged** (works): t-libs'
  `hashmap` and `heap` list only `alloc`, so `set`/`get`/`keys` run on
  bare metal, over platform.c's 100-line allocator.
- **Out of memory and panics on bare metal** (works): `exhaust` ends with
  `out of memory for 65536 slots` and its line, `panic` with its message
  and line, a stray trap with its cause, each over the serial port, and
  QEMU exits 1. `implicit_panics` with `--deny-warnings` holds in the
  shell and the kernel alike.
- **`Write` for a UART** (works): `type Error = !`, `effect e = {}`, and
  the shell, generic over any `Write`, writes to it and to a `String` in
  its tests alike; `into_ok()` where it can't fail.
