const std = @import("std");
const microzig = @import("microzig");

comptime {
    _ = microzig.export_startup();
}

// aviron debug device registers (data-space addresses):
const dbg_stdio: *volatile u8 = @ptrFromInt(0x0001);
const dbg_exit: *allowzero volatile u8 = @ptrFromInt(0x0000);

fn put(b: u8) void {
    dbg_stdio.* = b;
}

fn put16(v: u16) void {
    put(@truncate(v));
    put(@truncate(v >> 8));
}

fn put32(v: u32) void {
    put(@truncate(v));
    put(@truncate(v >> 8));
    put(@truncate(v >> 16));
    put(@truncate(v >> 24));
}

fn fail() noreturn {
    dbg_exit.* = 1;
    while (true) {}
}

noinline fn div16(a: u16, b: u16) u16 {
    return a / b;
}
noinline fn mod16(a: u16, b: u16) u16 {
    return a % b;
}
noinline fn divmod16(a: u16, b: u16) struct { q: u16, r: u16 } {
    return .{ .q = a / b, .r = a % b };
}
noinline fn div32(a: u32, b: u32) u32 {
    return a / b;
}
noinline fn rem32(a: u32, b: u32) u32 {
    return a % b;
}
noinline fn mul32(a: i32, b: i32) i32 {
    return a *% b;
}
noinline fn div8(a: u8, b: u8) u8 {
    return a / b;
}
noinline fn mod8(a: u8, b: u8) u8 {
    return a % b;
}
noinline fn sdiv16(a: i16, b: i16) i16 {
    return @divTrunc(a, b);
}
noinline fn srem16(a: i16, b: i16) i16 {
    return @rem(a, b);
}
noinline fn sdiv32(a: i32, b: i32) i32 {
    return @divTrunc(a, b);
}
noinline fn srem32(a: i32, b: i32) i32 {
    return @rem(a, b);
}

// Runtime inputs (volatile reads defeat constant folding).
var inputs linksection(".data") = extern struct {
    a16: u16 = 65535,
    b16: u16 = 10,
    z16: u16 = 0,
    d16: u16 = 12345,
    a32: u32 = 1_000_000_007,
    b32: u32 = 97,
    f32_: u32 = 4_294_967_295,
    g32: u32 = 4096,
    m1: i32 = -123456789,
    m2: i32 = 300,
    a8: u8 = 200,
    b8: u8 = 7,
    sa16: i16 = -1000,
    sb16: i16 = 3,
    sa32: i32 = -100000,
    sb32: i32 = 7,
}{};

pub fn main() void {
    const in = @volatileCast(&inputs);

    // Emit raw results as computed, THEN self-check, so emulation reveals
    // exact values even when a check would fail.
    const q3 = div32(in.a32, in.b32); // expect 10309278 = 0x009D3B1E
    const r3 = rem32(in.a32, in.b32); // expect 41
    put(0x51);
    put32(q3);
    put(0x52);
    put32(r3);

    const p = mul32(in.m1, in.m2);
    put(0x53);
    put32(@bitCast(p));

    // 16-bit divide and modulo, separate call sites.
    const q1 = div16(in.a16, in.b16); // expect 6553
    const r1 = mod16(in.a16, in.b16); // expect 5
    put(0x54);
    put16(q1);
    put16(r1);

    // 16-bit quotient AND remainder consumed from one site (packed return ABI).
    const dm = divmod16(in.a16, in.b16);
    put(0x55);
    put16(dm.q);
    put16(dm.r);

    // Zero dividend edge case.
    const q0 = divmod16(in.z16, in.d16); // expect q=0 r=0
    put(0x56);
    put16(q0.q);
    put16(q0.r);

    // All-ones dividend.
    const qf = div32(in.f32_, in.g32); // expect 1048575
    const rf = rem32(in.f32_, in.g32); // expect 4095
    put(0x57);
    put32(qf);
    put32(rf);

    put16(q1);
    put16(r1);
    put16(dm.q);
    put16(dm.r);
    put16(q0.q);
    put16(q0.r);
    put32(q3);
    put32(r3);
    put32(qf);
    put32(rf);
    put32(@bitCast(p));

    // Independent comptime cross-check (host arbitrary-precision math).
    const ok =
        q1 == 6553 and r1 == 5 and
        dm.q == 6553 and dm.r == 5 and
        q0.q == 0 and q0.r == 0 and
        q3 == 10309278 and r3 == 41 and
        qf == 1048575 and rf == 4095 and
        p == @as(i32, @truncate(-37_037_036_700));

    if (!ok) fail();

    // 8-bit and signed division paths.
    const q8 = div8(in.a8, in.b8); // 28
    const r8v = mod8(in.a8, in.b8); // 4
    put(0x58);
    put(q8);
    put(r8v);

    const sq16 = sdiv16(in.sa16, in.sb16); // -333
    const sr16 = srem16(in.sa16, in.sb16); // -1
    put(0x59);
    put16(@bitCast(sq16));
    put16(@bitCast(sr16));

    const sq32 = sdiv32(in.sa32, in.sb32); // -14285
    const sr32 = srem32(in.sa32, in.sb32); // -5
    put(0x5A);
    put32(@bitCast(sq32));
    put32(@bitCast(sr32));

    if (!(q8 == 28 and r8v == 4)) {
        dbg_exit.* = 8;
        while (true) {}
    }
    put(0x71);
    if (!(sq16 == -333 and sr16 == -1)) {
        dbg_exit.* = 16;
        while (true) {}
    }
    put(0x72);
    if (!(sq32 == -14285 and sr32 == -5)) {
        // Distinguish which half mismatched and emit raw values.
        put(0x7E);
        put32(@bitCast(sq32));
        put(0x7F);
        put32(@bitCast(sr32));
        if (sq32 != -14285) {
            dbg_exit.* = 33;
        } else {
            dbg_exit.* = 34;
        }
        while (true) {}
    }

    put(0xAA);
    put(0xBB);
    dbg_exit.* = 0;
    while (true) {}
}
