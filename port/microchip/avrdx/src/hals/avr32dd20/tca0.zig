//! TCA0 - 16-bit Timer/Counter Type A.
//!
//! DS40002413 section 23 "TCA - 16-bit Timer/Counter Type A", page 223.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=223
//!
//! TCA0 has two personalities selected by CTRLD.SPLITM: one 16-bit counter
//! with three compare channels (`single`), or two independent 8-bit counters
//! with three compare channels each (`split`). They share a register block at
//! different widths, so each lives in its own namespace here and the mode is
//! chosen by which one you call.

const regs = @import("registers.zig");

/// CTRLA.CLKSEL, bits 3:1. Prescales CLK_PER for the whole peripheral, in both
/// single and split mode.
pub const ClockSelect = enum(u8) {
    div1 = 0x0,
    div2 = 0x1,
    div4 = 0x2,
    div8 = 0x3,
    div16 = 0x4,
    div64 = 0x5,
    div256 = 0x6,
    div1024 = 0x7,

    pub fn divisor(c: ClockSelect) u16 {
        return switch (c) {
            .div1 => 1,
            .div2 => 2,
            .div4 => 4,
            .div8 => 8,
            .div16 => 16,
            .div64 => 64,
            .div256 => 256,
            .div1024 => 1024,
        };
    }
};

/// Stop the timer and return the whole peripheral to its reset configuration.
pub fn reset() void {
    regs.write(regs.tca0.single.ctrla, 0);
    regs.write(regs.tca0.single.ctrld, 0);
    regs.write(regs.tca0.single.ctrlb, 0);
}

/// Single (16-bit) mode.
pub const single = struct {
    const r = regs.tca0.single;

    /// CTRLB.WGMODE, bits 2:0.
    ///
    /// DS40002413 section 23.3.3.4.1 "Waveform Generation", page 228.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=228
    pub const Waveform = enum(u8) {
        /// Counter only; PER is TOP, no waveform output.
        normal = 0x0,
        /// Frequency generation: WO0 toggles on every CMP0 match, so the
        /// output is CLK_TCA / (2 * (CMP0 + 1)).
        frequency = 0x1,
        /// Single-slope PWM. Period is PER + 1, duty is CMPn.
        /// Section 23.3.3.4.3, page 230.
        single_slope = 0x3,
        /// Dual-slope PWM, overflow interrupt at TOP.
        dual_slope_top = 0x5,
        /// Dual-slope PWM, overflow interrupt at both TOP and BOTTOM.
        dual_slope_both = 0x6,
        /// Dual-slope PWM, overflow interrupt at BOTTOM. Period is 2 * PER.
        /// Section 23.3.3.4.4, page 231.
        dual_slope_bottom = 0x7,
    };

    /// The three compare channels. On the 20-pin package these reach
    /// PA0/PA1/PA2 (or PC1..PC3, or PD4/PD5) depending on `portmux.set_tca0`.
    pub const Channel = enum(u2) { cmp0 = 0, cmp1 = 1, cmp2 = 2 };

    pub const Config = struct {
        waveform: Waveform = .single_slope,
        clock: ClockSelect = .div1,
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

    /// Configure and start the timer.
    ///
    /// DS40002413 section 23.3.3.2 "Double Buffering", page 226: PER and CMPn
    /// have shadow registers, and writing the *BUF alias defers the update to
    /// the next UPDATE condition. Configuration happens with the timer
    /// stopped, so this writes PER/CMPn directly and leaves the buffered
    /// aliases for `set_period`/`set_compare` at run time.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=226
    pub fn configure(config: Config) void {
        regs.write(r.ctrla, 0);
        // Leave split mode if a previous configuration selected it.
        regs.write(r.ctrld, 0);

        regs.mem16(r.per).* = config.period;
        regs.mem16(r.cmp0).* = config.compare[0];
        regs.mem16(r.cmp1).* = config.compare[1];
        regs.mem16(r.cmp2).* = config.compare[2];

        var ctrlb: u8 = @intFromEnum(config.waveform);
        if (config.enable_output[0]) ctrlb |= regs.bit(regs.tca0.cmp0en);
        if (config.enable_output[1]) ctrlb |= regs.bit(regs.tca0.cmp1en);
        if (config.enable_output[2]) ctrlb |= regs.bit(regs.tca0.cmp2en);
        if (config.auto_lock_update) ctrlb |= regs.bit(regs.tca0.alupd);
        regs.write(r.ctrlb, ctrlb);

        var ctrla: u8 = (@as(u8, @intFromEnum(config.clock)) << 1) | regs.bit(regs.tca0.enable);
        if (config.run_standby) ctrla |= regs.bit(regs.tca0.runstdby);
        regs.write(r.ctrla, ctrla);
    }

    pub fn start() void {
        regs.set_bits(r.ctrla, regs.bit(regs.tca0.enable));
    }

    pub fn stop() void {
        regs.clear_bits(r.ctrla, regs.bit(regs.tca0.enable));
    }

    /// Change TOP through the buffered register, so the running period is only
    /// replaced at the next update condition rather than mid-cycle.
    pub fn set_period(value: u16) void {
        regs.mem16(r.perbuf).* = value;
    }

    /// Change a channel's duty cycle through its buffered register.
    pub fn set_compare(channel: Channel, value: u16) void {
        const address = switch (channel) {
            .cmp0 => r.cmp0buf,
            .cmp1 => r.cmp1buf,
            .cmp2 => r.cmp2buf,
        };
        regs.mem16(address).* = value;
    }

    /// Enable or disable a channel's waveform output at run time.
    pub fn set_output_enabled(channel: Channel, enable: bool) void {
        const mask = switch (channel) {
            .cmp0 => regs.bit(regs.tca0.cmp0en),
            .cmp1 => regs.bit(regs.tca0.cmp1en),
            .cmp2 => regs.bit(regs.tca0.cmp2en),
        };
        if (enable) regs.set_bits(r.ctrlb, mask) else regs.clear_bits(r.ctrlb, mask);
    }

    pub fn counter() u16 {
        return regs.mem16(r.cnt).*;
    }

    pub fn set_counter(value: u16) void {
        regs.mem16(r.cnt).* = value;
    }

    /// Force a restart from BOTTOM (CTRLESET.CMD = RESTART).
    ///
    /// DS40002413 section 23.3.3.5 "Timer/Counter Commands", page 232.
    pub fn restart() void {
        regs.write(r.ctrleset, 0x02 << 2);
    }

    pub fn enable_overflow_interrupt() void {
        regs.set_bits(r.intctrl, regs.bit(regs.tca0.ovf));
    }

    pub fn enable_compare_interrupt(channel: Channel) void {
        regs.set_bits(r.intctrl, compare_flag(channel));
    }

    pub fn disable_compare_interrupt(channel: Channel) void {
        regs.clear_bits(r.intctrl, compare_flag(channel));
    }

    pub fn overflow_pending() bool {
        return (regs.read(r.intflags) & regs.bit(regs.tca0.ovf)) != 0;
    }

    pub fn clear_overflow() void {
        regs.write(r.intflags, regs.bit(regs.tca0.ovf));
    }

    pub fn compare_pending(channel: Channel) bool {
        return (regs.read(r.intflags) & compare_flag(channel)) != 0;
    }

    pub fn clear_compare(channel: Channel) void {
        regs.write(r.intflags, compare_flag(channel));
    }

    fn compare_flag(channel: Channel) u8 {
        return switch (channel) {
            .cmp0 => regs.bit(regs.tca0.cmp0),
            .cmp1 => regs.bit(regs.tca0.cmp1),
            .cmp2 => regs.bit(regs.tca0.cmp2),
        };
    }

    /// Period register value for a target PWM frequency in single-slope mode.
    ///
    /// Single-slope period is (PER + 1) counts, hence the -1. Returns null if
    /// the request does not fit in 16 bits at the given prescaler.
    pub fn period_for_hz(clk_per_hz: u32, clock: ClockSelect, target_hz: u32) ?u16 {
        if (target_hz == 0) return null;
        const ticks = clk_per_hz / clock.divisor() / target_hz;
        if (ticks == 0 or ticks > 0x1_0000) return null;
        return @intCast(ticks - 1);
    }
};

/// Split (dual 8-bit) mode.
///
/// DS40002413 section 23.3.3.6 "Split Mode - Two 8-Bit Timer/Counters",
/// page 233: the 16-bit counter is halved into LCNT and HCNT. Both halves
/// share CTRLA's prescaler, both count down, and only single-slope PWM is
/// available. This is what buys you six independent PWM channels from one
/// timer.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=233
pub const split = struct {
    const r = regs.tca0.split;

    /// Which half of the split timer. The low half drives WO0..WO2, the high
    /// half WO3..WO5.
    pub const Half = enum { low, high };

    pub const Channel = enum(u2) { cmp0 = 0, cmp1 = 1, cmp2 = 2 };

    pub const Config = struct {
        clock: ClockSelect = .div1,
        low_period: u8 = 0xFF,
        high_period: u8 = 0xFF,
        low_compare: [3]u8 = .{ 0, 0, 0 },
        high_compare: [3]u8 = .{ 0, 0, 0 },
        /// CTRLB.LCMPnEN / HCMPnEN, indexed as {low0, low1, low2, high0,
        /// high1, high2}.
        enable_output: [6]bool = .{false} ** 6,
        run_standby: bool = false,
    };

    pub fn configure(config: Config) void {
        regs.write(r.ctrla, 0);
        regs.write(r.ctrld, regs.bit(regs.tca0.splitm));

        regs.write(r.lper, config.low_period);
        regs.write(r.hper, config.high_period);
        regs.write(r.lcmp0, config.low_compare[0]);
        regs.write(r.lcmp1, config.low_compare[1]);
        regs.write(r.lcmp2, config.low_compare[2]);
        regs.write(r.hcmp0, config.high_compare[0]);
        regs.write(r.hcmp1, config.high_compare[1]);
        regs.write(r.hcmp2, config.high_compare[2]);

        // In split mode CTRLB is a plain output-enable mask: LCMP0..2 in bits
        // 0..2 and HCMP0..2 in bits 4..6.
        var ctrlb: u8 = 0;
        for (config.enable_output[0..3], 0..) |on, i| {
            if (on) ctrlb |= @as(u8, 1) << @intCast(i);
        }
        for (config.enable_output[3..6], 0..) |on, i| {
            if (on) ctrlb |= @as(u8, 1) << @intCast(i + 4);
        }
        regs.write(r.ctrlb, ctrlb);

        var ctrla: u8 = (@as(u8, @intFromEnum(config.clock)) << 1) | regs.bit(regs.tca0.enable);
        if (config.run_standby) ctrla |= regs.bit(regs.tca0.runstdby);
        regs.write(r.ctrla, ctrla);
    }

    pub fn stop() void {
        regs.clear_bits(r.ctrla, regs.bit(regs.tca0.enable));
    }

    pub fn set_period(half: Half, value: u8) void {
        regs.write(switch (half) {
            .low => r.lper,
            .high => r.hper,
        }, value);
    }

    pub fn set_compare(half: Half, channel: Channel, value: u8) void {
        const address = switch (half) {
            .low => switch (channel) {
                .cmp0 => r.lcmp0,
                .cmp1 => r.lcmp1,
                .cmp2 => r.lcmp2,
            },
            .high => switch (channel) {
                .cmp0 => r.hcmp0,
                .cmp1 => r.hcmp1,
                .cmp2 => r.hcmp2,
            },
        };
        regs.write(address, value);
    }

    pub fn counter(half: Half) u8 {
        return regs.read(switch (half) {
            .low => r.lcnt,
            .high => r.hcnt,
        });
    }

    /// Both halves count *down*, so the period event is an underflow rather
    /// than the overflow that single mode reports.
    pub fn enable_underflow_interrupt(half: Half) void {
        regs.set_bits(r.intctrl, underflow_flag(half));
    }

    pub fn disable_underflow_interrupt(half: Half) void {
        regs.clear_bits(r.intctrl, underflow_flag(half));
    }

    pub fn underflow_pending(half: Half) bool {
        return (regs.read(r.intflags) & underflow_flag(half)) != 0;
    }

    pub fn clear_underflow(half: Half) void {
        regs.write(r.intflags, underflow_flag(half));
    }

    /// Only the low half has compare interrupts in split mode; the high half's
    /// compare channels generate waveforms but no interrupt.
    pub fn enable_low_compare_interrupt(channel: Channel) void {
        regs.set_bits(r.intctrl, low_compare_flag(channel));
    }

    pub fn disable_low_compare_interrupt(channel: Channel) void {
        regs.clear_bits(r.intctrl, low_compare_flag(channel));
    }

    pub fn low_compare_pending(channel: Channel) bool {
        return (regs.read(r.intflags) & low_compare_flag(channel)) != 0;
    }

    pub fn clear_low_compare(channel: Channel) void {
        regs.write(r.intflags, low_compare_flag(channel));
    }

    fn underflow_flag(half: Half) u8 {
        return switch (half) {
            .low => regs.bit(0),
            .high => regs.bit(1),
        };
    }

    fn low_compare_flag(channel: Channel) u8 {
        return switch (channel) {
            .cmp0 => regs.bit(4),
            .cmp1 => regs.bit(5),
            .cmp2 => regs.bit(6),
        };
    }
};
