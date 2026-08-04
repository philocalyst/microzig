//! RTC - Real-Time Counter, and the PIT (Periodic Interrupt Timer) that shares
//! its clock domain.
//!
//! DS40002413 section 26 "RTC - Real-Time Counter", page 347.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=347
//!
//! The RTC and the PIT are two independent counters fed from the same CLK_RTC,
//! selected once via `set_clock_source`. The PIT is the one that survives
//! power-down sleep, which makes it the usual choice for a periodic wake-up.

const regs = @import("registers.zig");

/// RTC.CLKSEL - source for CLK_RTC. Shared by the RTC and the PIT.
pub const ClockSource = enum(u8) {
    /// 32.768 kHz from the internal OSC32K.
    osc32k = 0x0,
    /// 1.024 kHz from the internal OSC32K (OSC32K divided by 32).
    osc1k = 0x1,
    /// 32.768 kHz from an external crystal on XTAL32K1/2 (PA0/PA1).
    xosc32k = 0x2,
    /// External clock on the EXTCLK pin.
    extclk = 0x3,
};

/// RTC.CTRLA.PRESCALER, bits 6:3. Applies to the RTC counter only -- the PIT
/// takes CLK_RTC undivided and does its own division via `Pit.Period`.
pub const Prescaler = enum(u8) {
    div1 = 0x0,
    div2 = 0x1,
    div4 = 0x2,
    div8 = 0x3,
    div16 = 0x4,
    div32 = 0x5,
    div64 = 0x6,
    div128 = 0x7,
    div256 = 0x8,
    div512 = 0x9,
    div1024 = 0xA,
    div2048 = 0xB,
    div4096 = 0xC,
    div8192 = 0xD,
    div16384 = 0xE,
    div32768 = 0xF,
};

/// Select CLK_RTC.
///
/// DS40002413 section 26.4.1.1 "Configure the Clock CLK_RTC", page 348: this
/// must be done before enabling either counter, and the choice is shared, so
/// the RTC and the PIT cannot run from different sources.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=348
pub fn set_clock_source(source: ClockSource) void {
    regs.write(regs.rtc.clksel, @intFromEnum(source));
}

// -- Synchronization ---------------------------------------------------------
//
// The RTC runs in its own clock domain, so writes to CTRLA, CNT, PER and CMP
// take several CLK_RTC cycles to land and the matching STATUS bit reads busy
// meanwhile. Writing while busy is silently dropped.
// DS40002413 section 26.10 "Synchronization", page 352.
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=352

pub fn ctrla_busy() bool {
    return (regs.read(regs.rtc.status) & regs.bit(regs.rtc.ctrlabusy)) != 0;
}

pub fn count_busy() bool {
    return (regs.read(regs.rtc.status) & regs.bit(regs.rtc.cntbusy)) != 0;
}

pub fn period_busy() bool {
    return (regs.read(regs.rtc.status) & regs.bit(regs.rtc.perbusy)) != 0;
}

pub fn compare_busy() bool {
    return (regs.read(regs.rtc.status) & regs.bit(regs.rtc.cmpbusy)) != 0;
}

// -- RTC counter -------------------------------------------------------------

pub const Config = struct {
    prescaler: Prescaler = .div1,
    /// Counter TOP. The overflow interrupt fires when CNT wraps past this.
    period: u16 = 0xFFFF,
    compare: u16 = 0,
    /// Keep counting in standby sleep.
    run_standby: bool = true,
};

/// Configure and start the RTC counter.
///
/// DS40002413 section 26.4.1.2 "Configure RTC", page 349.
pub fn configure(config: Config) void {
    while (ctrla_busy()) {}
    regs.write(regs.rtc.ctrla, 0);

    while (period_busy()) {}
    regs.mem16(regs.rtc.per).* = config.period;

    while (compare_busy()) {}
    regs.mem16(regs.rtc.cmp).* = config.compare;

    var ctrla: u8 = (@as(u8, @intFromEnum(config.prescaler)) << 3) | regs.bit(regs.rtc.rtcen);
    if (config.run_standby) ctrla |= regs.bit(regs.rtc.runstdby);

    while (ctrla_busy()) {}
    regs.write(regs.rtc.ctrla, ctrla);
}

pub fn stop() void {
    while (ctrla_busy()) {}
    regs.clear_bits(regs.rtc.ctrla, regs.bit(regs.rtc.rtcen));
}

pub fn count() u16 {
    return regs.mem16(regs.rtc.cnt).*;
}

pub fn set_count(value: u16) void {
    while (count_busy()) {}
    regs.mem16(regs.rtc.cnt).* = value;
}

pub fn set_period(value: u16) void {
    while (period_busy()) {}
    regs.mem16(regs.rtc.per).* = value;
}

pub fn set_compare(value: u16) void {
    while (compare_busy()) {}
    regs.mem16(regs.rtc.cmp).* = value;
}

pub fn enable_overflow_interrupt() void {
    regs.set_bits(regs.rtc.intctrl, regs.bit(regs.rtc.ovf));
}

pub fn enable_compare_interrupt() void {
    regs.set_bits(regs.rtc.intctrl, regs.bit(regs.rtc.cmp_bit));
}

pub fn disable_interrupts() void {
    regs.write(regs.rtc.intctrl, 0);
}

pub fn overflow_pending() bool {
    return (regs.read(regs.rtc.intflags) & regs.bit(regs.rtc.ovf)) != 0;
}

pub fn compare_pending() bool {
    return (regs.read(regs.rtc.intflags) & regs.bit(regs.rtc.cmp_bit)) != 0;
}

pub fn clear_overflow() void {
    regs.write(regs.rtc.intflags, regs.bit(regs.rtc.ovf));
}

pub fn clear_compare() void {
    regs.write(regs.rtc.intflags, regs.bit(regs.rtc.cmp_bit));
}

/// Apply the crystal error correction value in RTC.CALIB and enable
/// correction.
///
/// DS40002413 section 26.6 "Crystal Error Correction", page 350: correction
/// works by inserting or skipping CLK_RTC cycles, so `error_value` is a count
/// (0..127) and `negative` chooses the direction via CALIB.SIGN.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=350
pub fn set_calibration(error_value: u7, negative: bool) void {
    regs.write(regs.rtc.calib, @as(u8, error_value) | (if (negative) @as(u8, 0x80) else 0));
    while (ctrla_busy()) {}
    regs.set_bits(regs.rtc.ctrla, regs.bit(regs.rtc.corren));
}

// -- PIT ---------------------------------------------------------------------

/// Periodic Interrupt Timer.
///
/// DS40002413 section 26.5 "PIT Functional Description", page 349.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=349
pub const pit = struct {
    /// PITCTRLA.PERIOD, bits 6:3, in CLK_RTC cycles. At the usual 32.768 kHz
    /// these run from ~122 us (`cycles4`) to 1 s (`cycles32768`).
    pub const Period = enum(u8) {
        off = 0x0,
        cycles4 = 0x1,
        cycles8 = 0x2,
        cycles16 = 0x3,
        cycles32 = 0x4,
        cycles64 = 0x5,
        cycles128 = 0x6,
        cycles256 = 0x7,
        cycles512 = 0x8,
        cycles1024 = 0x9,
        cycles2048 = 0xA,
        cycles4096 = 0xB,
        cycles8192 = 0xC,
        cycles16384 = 0xD,
        cycles32768 = 0xE,

        /// Number of CLK_RTC cycles between ticks. Encoding n maps to
        /// 4 * 2^(n-1), i.e. 1 << (n + 1).
        pub fn cycles(p: Period) u16 {
            return switch (p) {
                .off => 0,
                else => @as(u16, 1) << @intCast(@intFromEnum(p) + 1),
            };
        }
    };

    /// Start the PIT.
    ///
    /// DS40002413 section 26.5.2.1 "Enabling and Disabling", page 349: PITCTRLA
    /// is synchronized like the RTC's CTRLA, so wait out PITSTATUS.CTRLBUSY
    /// first or the write is dropped.
    pub fn configure(period: Period, interrupt: bool) void {
        while (busy()) {}
        regs.write(
            regs.rtc.pitctrla,
            (@as(u8, @intFromEnum(period)) << 3) | regs.bit(regs.rtc.piten),
        );
        regs.write(regs.rtc.pitintctrl, if (interrupt) regs.bit(regs.rtc.pi) else 0);
    }

    pub fn stop() void {
        while (busy()) {}
        regs.write(regs.rtc.pitctrla, 0);
    }

    pub fn busy() bool {
        return (regs.read(regs.rtc.pitstatus) & regs.bit(regs.rtc.ctrlbusy)) != 0;
    }

    pub fn pending() bool {
        return (regs.read(regs.rtc.pitintflags) & regs.bit(regs.rtc.pi)) != 0;
    }

    pub fn clear_interrupt() void {
        regs.write(regs.rtc.pitintflags, regs.bit(regs.rtc.pi));
    }

    /// Block until the next PIT tick, polling the flag.
    ///
    /// Requires the PIT to be running; pair with `sleep.enter(.power_down)`
    /// instead if you want the CPU to actually stop.
    pub fn wait_tick() void {
        clear_interrupt();
        while (!pending()) {}
        clear_interrupt();
    }
};
