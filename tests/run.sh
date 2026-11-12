#!/bin/sh
# Checks t-metal: the kernel and the shell type-check with no warnings (so
# nothing in them can panic: they ask for `implicit_panics`), everything is
# formatted, their tests pass, the kernel builds for the freestanding
# target, and what it writes on QEMU for each session in tests/sessions is
# tests/expected.txt. Run from anywhere.
#
# Needs `t` on PATH, and clang (with the riscv64 target), ld.lld and
# qemu-system-riscv64, or what $CC, $LD and $QEMU name.
# BLESS=1 rewrites tests/expected.txt with what it writes now.
set -eu
cd "$(dirname "$0")/.."

CC=${CC:-clang}
LD=${LD:-ld.lld}
QEMU=${QEMU:-qemu-system-riscv64}
export CC
# riscv64 with the integer, multiply, atomic and compressed extensions, and
# the CSR instructions start.S uses; code anywhere in memory (`medany`), as
# RAM starts at 0x8000_0000.
FLAGS="--target=riscv64-unknown-elf -march=rv64imac_zicsr -mabi=lp64 -mcmodel=medany"

t check --deny-warnings shell/lib.t
t check --deny-warnings main.t
t fmt --check ./*.t shell/*.t
t test --deny-warnings shell/lib.t
# Each test of the kernel's is a hosted program of its own, whose platform
# is the C library's: its exports are T functions there.
t test --deny-warnings main.t

mkdir -p build
T_LANG_CFLAGS="$FLAGS" t build --target freestanding -o build/kernel.o main.t
# shellcheck disable=SC2086 # each word of $FLAGS is a flag
$CC $FLAGS -ffreestanding -O2 -Wall -Wextra -Werror -c boot/platform.c -o build/platform.o
# shellcheck disable=SC2086
$CC $FLAGS -c boot/start.S -o build/start.o
$LD -T boot/kernel.ld -o build/kernel.elf build/start.o build/kernel.o build/platform.o

# Runs the kernel with session $1 typed at its serial port, and writes what
# it writes back, and how QEMU ended: each session ends by stopping the
# machine. The timer's numbers differ from run to run, as does where a trap
# came from, from build to build, so they're left out.
run() {
    status=0
    timeout 60 "$QEMU" -machine virt -bios none -display none -serial stdio -monitor none \
        -kernel build/kernel.elf < "$1" > build/raw.txt || status=$?
    tr -d '\r' < build/raw.txt |
        sed -E 's/^up [0-9]+ ms, [0-9]+ timer interrupts$/up N ms, M timer interrupts/' |
        sed -E 's/ at 0x[0-9a-f]{16}$/ at 0xADDRESS/'
    echo "[exit $status]"
}

transcript() {
    for session in tests/sessions/*.txt; do
        echo "== $session"
        run "$session"
    done
}

if [ "${BLESS:-}" = 1 ]; then
    transcript > tests/expected.txt
    echo "wrote tests/expected.txt"
    exit 0
fi

transcript > build/actual.txt
if ! diff -u tests/expected.txt build/actual.txt; then
    echo "FAIL: what the kernel writes differs from tests/expected.txt"
    exit 1
fi
echo "ok"
