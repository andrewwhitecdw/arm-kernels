//
// SPDX-License-Identifier: BSD-3-Clause
//
// Stub kernel for tests/test_driver_extern_types.sh
//
// Mimics the kgen.py-generated kernel translation units: the bookkeeping
// globals are defined as `unsigned long`. driver.cpp must declare them
// with the same type or the program has an ODR violation and reads the
// values through the wrong type (undefined behavior).

const char * description = "stub_kernel";

unsigned long block_inst = 16;
// Deliberately set bits above bit 31 so that a driver reading this value
// through `extern int` observes the wrong low 32 bits.
unsigned long block_ops  = (1ul << 32) + 16;
unsigned long unroll     = 4;

void kernel(unsigned long)
{
    // No-op: the real kernels contain ARM NEON/SVE inline assembly and can
    // only run on aarch64. The driver only needs a callable symbol.
}
