//! Minimal integer runtime for AVR.
//!
//! LLVM lowers 32-bit multiplication and 16/32-bit division on AVR to calls
//! into the compiler runtime (`__mulsi3`, `__udivmodsi4`, `__udivmodhi4`).
//! Zig's bundled compiler_rt does not build for AVR, so MicroZig ships these
//! three routines here instead; they are small, dependency-free and match the
//! register conventions the generated callers use:
//!
//! - `__mulsi3(a, b) -> a*b`, both sides treat the values as bit patterns.
//! - `__udivmodsi4(a, b) -> packed u64` (low 32 = quotient, high 32 = remainder).
//!   Despite the libgcc-style name there is no remainder out-pointer; LLVM's
//!   AVR backend expects the packed register form.
//! - `__udivmodhi4(a, b) -> packed u32` (low 16 = quotient, high 16 = remainder).
//!   This matches the AVR GCC special calling convention (quot in R23:R22,
//!   rem in R25:R24), which is what LLVM emits call sites for.
//!
//! The arithmetic itself is plain shift-and-subtract/add so it cannot recurse
//! back into the runtime.

fn u16_divmod(num_in: u16, den: u16) struct { quot: u16, rem: u16 } {
    var quot: u16 = 0;
    var rem: u16 = 0;
    var num = num_in;
    var i: u8 = 16;
    while (i != 0) : (i -= 1) {
        rem = (rem << 1) | ((num >> 15) & 1);
        num <<= 1;
        quot <<= 1;
        if (rem >= den) {
            rem -= den;
            quot |= 1;
        }
    }
    return .{ .quot = quot, .rem = rem };
}

test u16_divmod {
    const cases = [_][3]u16{
        .{ 7, 5, 1 },
        .{ 65535, 10, 6553 },
        .{ 100, 100, 1 },
        .{ 0, 7, 0 },
    };
    for (cases) |c| {
        const r = u16_divmod(c[0], c[1]);
        try @import("std").testing.expectEqual(c[2], r.quot);
    }
    const r = u16_divmod(65535, 10);
    try @import("std").testing.expectEqual(@as(u16, 5), r.rem);
}

/// 16-bit unsigned division. AVR GCC/LLVM special ABI: quotient in R23:R22,
/// remainder in R25:R24 — identical to returning a little-endian packed `u32`
/// with the quotient in the low half-word.
pub export fn __udivmodhi4(num: u16, den: u16) callconv(.c) u32 {
    const r = u16_divmod(num, den);
    return (@as(u32, r.rem) << 16) | r.quot;
}

fn u32_divmod(num_in: u32, den: u32) struct { quot: u32, rem: u32 } {
    var quot: u32 = 0;
    var rem: u32 = 0;
    var num = num_in;
    var i: u8 = 32;
    while (i != 0) : (i -= 1) {
        rem = (rem << 1) | ((num >> 31) & 1);
        num <<= 1;
        quot <<= 1;
        if (rem >= den) {
            rem -= den;
            quot |= 1;
        }
    }
    return .{ .quot = quot, .rem = rem };
}

test u32_divmod {
    const cases = [_][3]u32{
        .{ 24_000_000, 1_000, 24_000 },
        .{ 1_000_000_007, 97, 10_309_278 },
        .{ 0, 12345, 0 },
    };
    for (cases) |c| {
        const r = u32_divmod(c[0], c[1]);
        try @import("std").testing.expectEqual(c[2], r.quot);
        try @import("std").testing.expectEqual(c[0] % c[1], r.rem);
    }
}

pub export fn __udivmodsi4(a: u32, b: u32) callconv(.c) u64 {
    // LLVM's AVR backend expects the packed form: quotient in the low 32 bits
    // (returned in r21:r18) and remainder in the high 32 bits (r25:r22).
    // There is no pointer argument despite the libgcc-style name.
    const r = u32_divmod(a, b);
    return (@as(u64, r.rem) << 32) | r.quot;
}

fn u8_divmod(num_in: u8, den: u8) struct { quot: u8, rem: u8 } {
    var quot: u8 = 0;
    var rem: u8 = 0;
    var num = num_in;
    var i: u8 = 8;
    while (i != 0) : (i -= 1) {
        rem = (rem << 1) | ((num >> 7) & 1);
        num <<= 1;
        quot <<= 1;
        if (rem >= den) {
            rem -= den;
            quot |= 1;
        }
    }
    return .{ .quot = quot, .rem = rem };
}

test u8_divmod {
    const cases = [_][4]u8{
        .{ 200, 7, 28, 4 },
        .{ 255, 255, 1, 0 },
        .{ 0, 9, 0, 0 },
    };
    for (cases) |c| {
        const r = u8_divmod(c[0], c[1]);
        try @import("std").testing.expectEqual(c[2], r.quot);
        try @import("std").testing.expectEqual(c[3], r.rem);
    }
}

/// 8-bit unsigned division. LLVM's AVR backend expects the packed struct
/// convention documented in compiler-rt's avr/divmodqi4.S: quotient returned
/// via R24 (low byte) and remainder via R25 (high byte), i.e. one 16-bit
/// return value.
pub export fn __udivmodqi4(a: u8, b: u8) callconv(.c) u16 {
    const r = u8_divmod(a, b);
    return (@as(u16, r.rem) << 8) | r.quot;
}

/// 16-bit signed division. Same packed register shape as `__udivmodhi4`:
/// quotient low word, remainder high word (returned as one `u32` so Zig does
/// not insert an sret pointer the way an `extern struct` / `i32` pair might).
pub export fn __divmodhi4(a: i16, b: i16) callconv(.c) u32 {
    const neg_q = (a < 0) != (b < 0);
    const ua: u16 = @abs(a);
    const ub: u16 = @abs(b);
    const r = u16_divmod(ua, ub);
    const quot: u16 = if (neg_q) -%r.quot else r.quot;
    const rem: u16 = if (a < 0) -%r.rem else r.rem;
    return (@as(u32, rem) << 16) | quot;
}

test __divmodhi4 {
    // Packed form: remainder in the high 16 bits, quotient in the low 16.
    const q = __divmodhi4(-1000, 3);
    const q_rem: i16 = @bitCast(@as(u16, @truncate(q >> 16)));
    const q_quot: i16 = @bitCast(@as(u16, @truncate(q)));
    try @import("std").testing.expectEqual(@as(i16, -333), q_quot);
    try @import("std").testing.expectEqual(@as(i16, -1), q_rem);
    const p = __divmodhi4(1000, -3);
    const p_rem: i16 = @bitCast(@as(u16, @truncate(p >> 16)));
    const p_quot: i16 = @bitCast(@as(u16, @truncate(p)));
    try @import("std").testing.expectEqual(@as(i16, -333), p_quot);
    try @import("std").testing.expectEqual(@as(i16, 1), p_rem);
}

/// 8-bit signed division. Packed like `__divmodqi4`: quotient R24, remainder
/// R25.
pub export fn __divmodqi4(a: i8, b: i8) callconv(.c) u16 {
    const neg_q = (a < 0) != (b < 0);
    const ua: u8 = @abs(a);
    const ub: u8 = @abs(b);
    const r = u8_divmod(ua, ub);
    const quot: u8 = if (neg_q) -%r.quot else r.quot;
    const rem: u8 = if (a < 0) -%r.rem else r.rem;
    return (@as(u16, rem) << 8) | quot;
}

test __divmodqi4 {
    const r = __divmodqi4(-128, 3);
    const expected = (@as(u16, @as(u8, @bitCast(@as(i8, -2)))) << 8) | @as(u8, @bitCast(@as(i8, -42)));
    try @import("std").testing.expectEqual(expected, r);
}

/// 32-bit signed division. Packed like `__udivmodsi4`: quotient low 32 bits,
/// remainder high 32 bits of one 64-bit return value.
pub export fn __divmodsi4(a: i32, b: i32) callconv(.c) u64 {
    // NOTE: returns u64 rather than i64 on purpose -- Zig emits a hidden
    // sret pointer for i64 returns on AVR but passes u64 in registers, and
    // LLVM's caller side expects the packed register form.
    const neg_q = (a < 0) != (b < 0);
    const ua: u32 = @abs(a);
    const ub: u32 = @abs(b);
    const r = u32_divmod(ua, ub);
    const quot: u32 = if (neg_q) -%r.quot else r.quot;
    const rem: u32 = if (a < 0) -%r.rem else r.rem;
    return (@as(u64, rem) << 32) | quot;
}

test __divmodsi4 {
    // Packed form: remainder in the high 32 bits, quotient in the low 32.
    const r = __divmodsi4(-100000, 7);
    const rem_bits: u32 = @bitCast(@as(i32, -5));
    const quot_bits: u32 = @bitCast(@as(i32, -14285));
    const expected: u64 = (@as(u64, rem_bits) << 32) | quot_bits;
    try @import("std").testing.expectEqual(expected, r);
}

pub export fn __mulsi3(a: i32, b: i32) callconv(.c) i32 {
    var ua: u32 = @bitCast(a);
    var ub: u32 = @bitCast(b);
    var r: u32 = 0;

    while (ua > 0) {
        if ((ua & 1) != 0) r +%= ub;
        ua >>= 1;
        ub <<= 1;
    }

    return @bitCast(r);
}

test __mulsi3 {
    try @import("std").testing.expectEqual(@as(i32, -6), __mulsi3(-2, 3));
    try @import("std").testing.expectEqual(@as(i32, 90_000), __mulsi3(300, 300));
}
