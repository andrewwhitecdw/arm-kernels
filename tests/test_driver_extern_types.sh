#!/usr/bin/env bash
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Regression test: arithmetic/driver.cpp must declare the kgen.py-generated
# globals (block_inst, block_ops, unroll) as `extern unsigned long` to match
# the generated definitions. Declaring them `extern int` is an ODR violation
# and reads the values through the wrong type (undefined behavior).
#
# The test links driver.cpp against a stub kernel (no ARM assembly, so it
# runs on any host) two ways and fails if either check trips:
#
#   1. Link-time: `g++ -flto -Wodr` must not emit -Wlto-type-mismatch.
#   2. Run-time: the stub sets block_ops with bits above bit 31, so a driver
#      reading it through `int` reports a truncated "Ops/Iter".
#
set -euo pipefail

cd "$(dirname "$0")/.."

CXX="${CXX:-g++}"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

BIN="$TMPDIR_TEST/driver_stub"
LOG="$TMPDIR_TEST/build.log"

if ! "$CXX" -O2 -flto -Wodr -o "$BIN" \
        arithmetic/driver.cpp tests/stub_kernel.cpp 2>"$LOG"; then
    echo "FAIL: build error" >&2
    cat "$LOG" >&2
    exit 1
fi

if grep -q 'lto-type-mismatch' "$LOG"; then
    echo "FAIL: extern declaration type mismatch detected at link time:" >&2
    grep 'lto-type-mismatch' "$LOG" >&2
    exit 1
fi

# unroll(4) * block_inst(16)                       = 64
# unroll(4) * block_ops((1<<32)+16)                = 17179869248
EXPECTED_INST_PER_ITER=64
EXPECTED_OPS_PER_ITER=17179869248

OUT="$("$BIN")"

inst_per_iter="$(echo "$OUT" | awk -F';' '$1=="Inst/Iter"{print $2}')"
ops_per_iter="$(echo "$OUT" | awk -F';' '$1=="Ops/Iter"{print $2}')"

if [ "$inst_per_iter" != "$EXPECTED_INST_PER_ITER" ]; then
    echo "FAIL: Inst/Iter=$inst_per_iter, expected $EXPECTED_INST_PER_ITER" >&2
    exit 1
fi

if [ "$ops_per_iter" != "$EXPECTED_OPS_PER_ITER" ]; then
    echo "FAIL: Ops/Iter=$ops_per_iter, expected $EXPECTED_OPS_PER_ITER" >&2
    echo "(driver read block_ops through the wrong type and truncated it)" >&2
    exit 1
fi

echo "PASS: driver extern declarations match generated symbol types"
