# t-metal

A bare-metal riscv64 kernel written in T, the language at
`~/repos/tooling/t-lang` (GitHub: lkurcak/t-lang), for QEMU's `virt`
machine. Like tcalc, t-libs, t-nonograms and t-maze, part of its purpose
is to find out what using T is like, here for the freestanding target,
`extern fn`, `Volatile`, statics and `Atomic` (t-lang steps 38–41), which
no other program uses.

- `main.t` is the kernel's root; modules `board`, `uart`, `timer`, `trap`,
  `power`, `heap`. Every `extern fn` is in `main.t` (one in a module makes
  invalid C, FRICTION.md). `boot/` has start.S, the linker script and
  platform.c (the allocator and `mem*`, which T can't write yet).
- `shell/` is a library (line editor, commands, values) that touches no
  machine; its tests run hosted with `t test shell/lib.t`.
- Nothing panics but what's asked to: `#![warn(implicit_panics)]` in both,
  with `--deny-warnings` (and, for the kernel, run.sh fails on any output
  of `t build`, which has no `--deny-warnings`).
- `tests/run.sh` runs what CI runs, including each session in
  `tests/sessions` on QEMU against `tests/expected.txt`. `BLESS=1`
  rewrites the transcript. Needs clang (riscv64 target), ld.lld,
  qemu-system-riscv64.
- CI pins a `t` release (`t-version` + `t-sha256` in .github/workflows/t.yml,
  which calls forge's shared t-ci.yml and installs QEMU and lld first);
  forge bumps it after each t-lang release. t-libs is a git dependency of
  `shell`, pinned by `rev` in shell/t.toml.
- `FRICTION.md` is the friction log: label entries gap / by design / unsure
  / works, with the code that hit them. It's evidence for t-lang steps,
  planned in t-lang, not here. Don't change t-lang from here.
- `git` over ssh doesn't work in Claude's shell: push and fetch through
  `origin` with `-c url."https://github.com/".insteadOf=git@github.com:
  -c credential.helper='!gh auth git-credential'`.
