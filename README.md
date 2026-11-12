# t-metal

A [T](https://github.com/lkurcak/t-lang) program on bare metal: a small
kernel for a riscv64 machine with no operating system, QEMU's `virt`
board. It's the only program on the machine. It drives the devices itself,
through their registers: the serial port, the timer and its interrupt, and
the device that turns the machine off. It reads lines typed at the serial
port and runs each as a command. Partly it's here to find out what
writing such a program in T is like: what got in the way is in
[FRICTION.md](FRICTION.md).

```text
$ tests/run.sh   # builds build/kernel.elf
$ qemu-system-riscv64 -machine virt -bios none -nographic -kernel build/kernel.elf
t-metal: T on bare metal. Type `help` for the commands.
> set greeting hello, world
greeting = hello, world
> primes 1000000
78498 primes up to 1000000, the largest 999983
> uptime
up 5210 ms, 520 timer interrupts
> halt
```

(`-nographic` puts the serial port on the terminal; Ctrl-A X leaves QEMU.)

`help` lists the commands: `echo`, `uptime`, `sleep MS` (on the timer's
interrupts), `mem` (how the heap is doing), `set`/`get`/`del`/`keys` (over
t-libs' [hashmap](https://github.com/lkurcak/t-libs/tree/main/hashmap)),
`primes N`, and `halt`. Three more stop the machine on purpose, to show
how it fails: `panic`, `exhaust` (allocates until the heap runs out) and
`trap` (an instruction that traps). Each writes its message to the serial
port, and QEMU exits with 1.

## How it's put together

- `boot/start.S` makes a stack, zeroes the zeroed data, points traps at
  its trap vector and runs T's `main`; the trap vector calls T's `trap`.
  `boot/kernel.ld` puts it all at 0x8000_0000, then a 4 MiB heap and the
  stack.
- `boot/platform.c` is the part of the platform T can't write yet: the
  allocator the runtime calls (a free list per power-of-two size class),
  and `memcpy` and friends.
- `main.t` is the kernel's root: the loop that feeds the serial port to the
  shell, and every `extern fn`: the platform's `t_platform_write` and
  `t_platform_halt`, `trap` and `poweroff` for start.S, and the imports
  from start.S and platform.c. The modules are the board's devices:
  `board` (addresses, and the board as the shell sees it), `uart`,
  `timer`, `trap`, `power` and `heap`.
- `shell/` is a library: the line editor, the commands and the values
  `set` keeps. It touches no machine, only a `Machine` and a sink it's
  given, so its tests run on the hosted target.

## Checking it

`tests/run.sh` checks what CI checks: the shell type-checks with no
warnings, everything is formatted, the shell's tests pass, the kernel
builds for the freestanding target with no warnings, and what it writes on
QEMU for each session in `tests/sessions` is `tests/expected.txt`. It
needs `t`, clang with the riscv64 target, ld.lld and
`qemu-system-riscv64` (Debian and Ubuntu: `clang lld qemu-system-misc`).
