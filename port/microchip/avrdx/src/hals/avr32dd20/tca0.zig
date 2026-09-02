//! TCA0 - 16-bit Timer/Counter Type A, in single and split mode.
//!
//! DS40002413 section 23 "TCA - 16-Bit Timer/Counter Type A", page 221.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=221
//!
//! One instance on this part. `single` drives the 16-bit counter with three
//! compare channels; `split` re-purposes the same registers as two independent
//! 8-bit timers with six channels. The register overlays are exactly what the
//! generated union models, so both namespaces read/write through it.

const microzig = @import("microzig");

const tca0 = microzig.chip.peripherals.TCA0;
const gen = microzig.chip.types.peripherals.TCA;

/// CTRLA.CLKSEL for single mode. Re-exported from the generated layer.
pub const ClockSelect = gen.TCA_SINGLE_CLKSEL;

/// CTRLA.CLKSEL for split mode. Encodings match the single-mode set, but the
/// generated types keep them distinct so each mode's CTRLA gets its own kind.
pub const SplitClockSelect = gen.TCA_SPLIT_CLKSEL;

/// Numeric division factor of a TCA clock selection.
pub fn divisor(c: ClockSelect) u16 {
    return switch (c) {
        .DIV1 => 1,
        .DIV2 => 2,
        .DIV4 => 4,
        .DIV8 => 8,
        .DIV16 => 16,
        .DIV64 => 64,
        .DIV256 => 256,
        .DIV1024 => 1024,
    };
}

/// Stop the timer and return the whole peripheral to its reset configuration.
pub fn reset() void {
    tca0.SINGLE.CTRLA.write(.{
        .ENABLE = 0,
        .CLKSEL = .DIV1,
        .RUNSTDBY = 0,
    });
    tca0.SINGLE.CTRLD.write(.{ .SPLITM = 0 });
    tca0.SINGLE.CTRLB.write(.{
        .WGMODE = .NORMAL,
        .ALUPD = 0,
        .CMP0EN = 0,
        .CMP1EN = 0,
        .CMP2EN = 0,
    });
}

/// TCA_SINGLE.WGMODE re-exported for call sites.
pub const Waveform = gen.TCA_SINGLE_WGMODE;

/// The three compare channels of single mode / each half of split mode. On the
/// 20-pin package these reach PA0/PA1/PA2 (or PC1..PC3, or PD4/PD5) depending
/// on `portmux.set_tca0`.
pub const Channel = enum(u2) { cmp0 = 0, cmp1 = 1, cmp2 = 2 };

fn channel_bit(comptime n: comptime_int) u8 {
    return @as(u8, 1) << (4 + n);
}

/// Configuration for normal 16-bit timer/PWM operation.
pub const SingleConfig = struct {
    waveform: Waveform = .SINGLESLOPE,
    clock: ClockSelect = .DIV1,
    /// Counter TOP.
    period: u16 = 0xFFFF,
    compare: [3]u16 = .{ 0, 0, 0 },
    /// Which compare channels drive their waveform output pin.
    enable_output: [3]bool = .{ false, false, false },
    /// CTRLB.ALUPD: hold buffered updates until every enabled channel's
    /// buffer has been written, so a multi-channel duty change is applied
    /// atomically.
    auto_lock_update: bool = false,
    run_standby: bool = false,
};

/// API for the SINGLE register set (normal 16-bit mode).
pub const single = struct {
    /// Configure and start the timetca0.SINGLE.
    ///
    /// DS40002413 section 23.3.3.2 "Double Buffering", page 226: PER and CMPn
    /// have shadow registers, and writing the *BUF alias defers the update to
    /// the next UPDATE condition. Configuration happens with the timer
    /// stopped, so this writes PER/CMPn directly and leaves the buffered
    /// aliases for `set_period`/`set_compare` at run time.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=226
    pub fn configure(config: SingleConfig) void {
        tca0.SINGLE.CTRLA.write(.{
            .ENABLE = 0,
            .CLKSEL = config.clock,
            .RUNSTDBY = @intFromBool(config.run_standby),
        });
        // Leave SPLITM clear (single mode).
        tca0.SINGLE.CTRLD.write(.{ .SPLITM = 0 });

        tca0.SINGLE.PER = config.period;
        tca0.SINGLE.CMP0 = config.compare[0];
        tca0.SINGLE.CMP1 = config.compare[1];
        tca0.SINGLE.CMP2 = config.compare[2];

        tca0.SINGLE.CTRLB.write(.{
            .WGMODE = config.waveform,
            .ALUPD = @intFromBool(config.auto_lock_update),
            .CMP0EN = @intFromBool(config.enable_output[0]),
            .CMP1EN = @intFromBool(config.enable_output[1]),
            .CMP2EN = @intFromBool(config.enable_output[2]),
        });

        tca0.SINGLE.CTRLA.modify(.{ .ENABLE = 1 });
    }

    pub fn start() void {
        tca0.SINGLE.CTRLA.modify(.{ .ENABLE = 1 });
    }

    pub fn stop() void {
        tca0.SINGLE.CTRLA.modify(.{ .ENABLE = 0 });
    }

    /// Buffered period update; lands at the next UPDATE condition.
    pub fn set_period(value: u16) void {
        tca0.SINGLE.PERBUF = value;
    }

    /// Buffered compare update; lands at the next UPDATE condition.
    pub fn set_compare(channel: Channel, value: u16) void {
        switch (channel) {
            .cmp0 => tca0.SINGLE.CMP0BUF = value,
            .cmp1 => tca0.SINGLE.CMP1BUF = value,
            .cmp2 => tca0.SINGLE.CMP2BUF = value,
        }
    }

    pub fn set_output_enabled(channel: Channel, enable: bool) void {
        switch (channel) {
            inline else => |ch| {
                const field = comptime std.meta.stringToEnum(
                    std.meta.FieldEnum(@TypeOf(tca0.SINGLE.CTRLB.read())),
                    "CMP" ++ @tagName(ch)[3] ++ "EN",
                ).?;
                tca0.SINGLE.CTRLB.modify(@unionInit(@TypeOf(tca0.SINGLE.CTRLB.read()), @tagName(field), @intFromBool(enable)));
            },
        }
    }

    pub fn counter() u16 {
        return tca0.SINGLE.CNT;
    }

    pub fn set_counter(value: u16) void {
        tca0.SINGLE.CNT = value;
    }

    /// Force an UPDATE so buffered values take effect now (CTRLESET.CMD=UPDATE).
    pub fn restart() void {
        tca0.SINGLE.CTRLESET.write(.{ .DIR = .DOWN, .LUPD = false, .CMD = .UPDATE });
    }

    /// Hard-reset the timer's state machine. RESET clears the whole peripheral
    /// including CTRLA; it must be followed by a fresh configure().
    pub fn hard_reset() void {
        tca0.SINGLE.CTRLESET.write(.{ .DIR = .DOWN, .LUPD = false, .CMD = .RESET });
    }

    pub fn enable_overflow_interrupt() void {
        tca0.SINGLE.INTCTRL.modify(.{ .OVF = 1 });
    }

    pub fn enable_compare_interrupt(channel: Channel) void {
        switch (channel) {
            .cmp0 => tca0.SINGLE.INTCTRL.modify(.{ .CMP0 = 1 }),
            .cmp1 => tca0.SINGLE.INTCTRL.modify(.{ .CMP1 = 1 }),
            .cmp2 => tca0.SINGLE.INTCTRL.modify(.{ .CMP2 = 1 }),
        }
    }

    pub fn disable_compare_interrupt(channel: Channel) void {
        switch (channel) {
            .cmp0 => tca0.SINGLE.INTCTRL.modify(.{ .CMP0 = 0 }),
            .cmp1 => tca0.SINGLE.INTCTRL.modify(.{ .CMP1 = 0 }),
            .cmp2 => tca0.SINGLE.INTCTRL.modify(.{ .CMP2 = 0 }),
        }
    }

    pub fn overflow_pending() bool {
        return tca0.SINGLE.INTFLAGS.read().OVF != 0;
    }

    pub fn clear_overflow() void {
        tca0.SINGLE.INTFLAGS.write(.{ .OVF = 1, .CMP0 = 0, .CMP1 = 0, .CMP2 = 0 });
    }

    pub fn compare_pending(channel: Channel) bool {
        return switch (channel) {
            .cmp0 => tca0.SINGLE.INTFLAGS.read().CMP0 != 0,
            .cmp1 => tca0.SINGLE.INTFLAGS.read().CMP1 != 0,
            .cmp2 => tca0.SINGLE.INTFLAGS.read().CMP2 != 0,
        };
    }

    pub fn clear_compare(channel: Channel) void {
        switch (channel) {
            .cmp0 => tca0.SINGLE.INTFLAGS.write(.{ .OVF = 0, .CMP0 = 1, .CMP1 = 0, .CMP2 = 0 }),
            .cmp1 => tca0.SINGLE.INTFLAGS.write(.{ .OVF = 0, .CMP0 = 0, .CMP1 = 1, .CMP2 = 0 }),
            .cmp2 => tca0.SINGLE.INTFLAGS.write(.{ .OVF = 0, .CMP0 = 0, .CMP1 = 0, .CMP2 = 1 }),
        }
    }

    /// Largest TOP for which `target_hz` is reachable with `clock`.
    ///
    /// The PWM frequency in single-slope mode is CLK_TCA / (PER + 1), so
    /// PER = CLK_TCA/f - 1; returns null when f is out of range even at the
    /// extremes.
    pub fn period_for_hz(clk_per_hz: u32, clock: ClockSelect, target_hz: u32) ?u16 {
        if (target_hz == 0) return null;
        const clk_tca = clk_per_hz / divisor(clock);
        if (clk_tca < target_hz) return null;
        const per = clk_tca / target_hz;
        if (per == 0 or per > 0x10000) return null;
        return @intCast(per - 1);
    }
};

/// Configuration for split dual-8-bit PWM operation.
pub const SplitConfig = struct {
    clock: SplitClockSelect = .DIV1,
    low_period: u8 = 0xFF,
    high_period: u8 = 0xFF,
    low_compare: [3]u8 = .{ 0, 0, 0 },
    high_compare: [3]u8 = .{ 0, 0, 0 },
    /// CTRLB.LCMPnEN / HCMPnEN, indexed as {low0, low1, low2, high0, high1,
    /// high2}.
    enable_output: [6]bool = @splat(false),
    run_standby: bool = false,
};

const std = @import("std");

/// API for the SPLIT register set (two 8-bit PWM groups).
pub const split = struct {
    /// Which half of the split timetca0.SPLIT. The low half drives WO0..WO2, the high
    /// half WO3..WO5.
    pub const Half = enum { low, high };
    // Compare channels are shared with `single`; see the outer `Channel`.

    pub fn configure(config: SplitConfig) void {
        tca0.SPLIT.CTRLA.write(.{
            .ENABLE = 0,
            .CLKSEL = config.clock,
            .RUNSTDBY = @intFromBool(config.run_standby),
        });
        tca0.SPLIT.CTRLD.write(.{ .SPLITM = 1 });

        tca0.SPLIT.LPER = config.low_period;
        tca0.SPLIT.HPER = config.high_period;
        tca0.SPLIT.LCMP0 = config.low_compare[0];
        tca0.SPLIT.LCMP1 = config.low_compare[1];
        tca0.SPLIT.LCMP2 = config.low_compare[2];
        tca0.SPLIT.HCMP0 = config.high_compare[0];
        tca0.SPLIT.HCMP1 = config.high_compare[1];
        tca0.SPLIT.HCMP2 = config.high_compare[2];

        tca0.SPLIT.CTRLB.write(.{
            .LCMP0EN = @intFromBool(config.enable_output[0]),
            .LCMP1EN = @intFromBool(config.enable_output[1]),
            .LCMP2EN = @intFromBool(config.enable_output[2]),
            .HCMP0EN = @intFromBool(config.enable_output[3]),
            .HCMP1EN = @intFromBool(config.enable_output[4]),
            .HCMP2EN = @intFromBool(config.enable_output[5]),
        });

        tca0.SPLIT.CTRLA.modify(.{ .ENABLE = 1 });
    }

    pub fn stop() void {
        tca0.SPLIT.CTRLA.modify(.{ .ENABLE = 0 });
    }

    pub fn set_period(half: Half, value: u8) void {
        switch (half) {
            .low => tca0.SPLIT.LPER = value,
            .high => tca0.SPLIT.HPER = value,
        }
    }

    pub fn set_compare(half: Half, channel: Channel, value: u8) void {
        switch (half) {
            .low => switch (channel) {
                .cmp0 => tca0.SPLIT.LCMP0 = value,
                .cmp1 => tca0.SPLIT.LCMP1 = value,
                .cmp2 => tca0.SPLIT.LCMP2 = value,
            },
            .high => switch (channel) {
                .cmp0 => tca0.SPLIT.HCMP0 = value,
                .cmp1 => tca0.SPLIT.HCMP1 = value,
                .cmp2 => tca0.SPLIT.HCMP2 = value,
            },
        }
    }

    pub fn counter(half: Half) u8 {
        return switch (half) {
            .low => tca0.SPLIT.LCNT,
            .high => tca0.SPLIT.HCNT,
        };
    }

    pub fn enable_underflow_interrupt(half: Half) void {
        switch (half) {
            .low => tca0.SPLIT.INTCTRL.modify(.{ .LUNF = 1 }),
            .high => tca0.SPLIT.INTCTRL.modify(.{ .HUNF = 1 }),
        }
    }

    pub fn disable_underflow_interrupt(half: Half) void {
        switch (half) {
            .low => tca0.SPLIT.INTCTRL.modify(.{ .LUNF = 0 }),
            .high => tca0.SPLIT.INTCTRL.modify(.{ .HUNF = 0 }),
        }
    }

    pub fn underflow_pending(half: Half) bool {
        return switch (half) {
            .low => tca0.SPLIT.INTFLAGS.read().LUNF != 0,
            .high => tca0.SPLIT.INTFLAGS.read().HUNF != 0,
        };
    }

    pub fn clear_underflow(half: Half) void {
        switch (half) {
            // The split-mode flag register carries only LUNF/HUNF and the
            // low-byte compare flags; the high-byte comparators have none.
            .low => tca0.SPLIT.INTFLAGS.write(.{ .LUNF = 1, .HUNF = 0, .LCMP0 = 0, .LCMP1 = 0, .LCMP2 = 0 }),
            .high => tca0.SPLIT.INTFLAGS.write(.{ .LUNF = 0, .HUNF = 1, .LCMP0 = 0, .LCMP1 = 0, .LCMP2 = 0 }),
        }
    }
};
