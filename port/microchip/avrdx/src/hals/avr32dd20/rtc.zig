//! RTC - Real-Time Counter, and the PIT (Periodic Interrupt Timer) that shares
//! its clock domain.
//!
//! DS40002413 section 26 "RTC - Real-Time Counter", page 347.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=347
//!
//! The RTC and the PIT are two independent counters fed from the same CLK_RTC,
//! selected once via `set_clock_source`. The PIT is the one that survives
//! power-down sleep, which makes it the usual choice for a periodic wake-up.
//!
//! Events (section 26.7): the RTC has no EVTCTRL register. Overflow, compare,
//! and PIT period markers are *generators* into EVSYS (`RTC_OVF`, `RTC_CMP`,
//! `RTC_PIT_DIVxxxx` in each channel's generated enum). Wire them with
//! `evsys.set_generator`.
//!
//! Debug (section 26.11): `set_debug_run` / `pit.set_debug_run` control
//! DBGCTRL.DBGRUN and PITDBGCTRL.DBGRUN so the counters keep ticking while
//! the CPU is halted by the debugger.

const microzig = @import("microzig");

const rtc = microzig.chip.peripherals.RTC;
const gen = microzig.chip.types.peripherals.RTC;

/// RTC.CLKSEL - source for CLK_RTC. Shared by the RTC and the PIT; encodings
/// re-exported from the generated layer.
pub const ClockSource = gen.RTC_CLKSEL;

/// RTC.CTRLA.PRESCALER. Applies to the RTC counter only -- the PIT takes
/// CLK_RTC undivided and does its own division via `pit.Period`. Encodings
/// re-exported from the generated layer.
pub const Prescaler = gen.RTC_PRESCALER;

/// Select CLK_RTC.
///
/// DS40002413 section 26.4.1.1 "Configure the Clock CLK_RTC", page 348: this
/// must be done before enabling either counter, and the choice is shared, so
/// the RTC and the PIT cannot run from different sources.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=348
pub fn set_clock_source(source: ClockSource) void {
    rtc.CLKSEL.modify(.{ .CLKSEL = source });
}

// -- Synchronization ---------------------------------------------------------
//
// The RTC runs in its own clock domain, so writes to CTRLA, CNT, PER and CMP
// take several CLK_RTC cycles to land and the matching STATUS bit reads busy
// meanwhile. Writing while busy is silently dropped.
// DS40002413 section 26.10 "Synchronization", page 352.
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=352

/// True while the RTC is synchronizing CTRLA; writes then are lost.
pub fn ctrla_busy() bool {
    return rtc.STATUS.read().CTRLABUSY != 0;
}

/// True while COUNT is still syncing from the CLK_RTC domain.
pub fn count_busy() bool {
    return rtc.STATUS.read().CNTBUSY != 0;
}

/// True while PER is still syncing.
pub fn period_busy() bool {
    return rtc.STATUS.read().PERBUSY != 0;
}

/// True while CMP is still syncing.
pub fn compare_busy() bool {
    return rtc.STATUS.read().CMPBUSY != 0;
}

// -- RTC counter -------------------------------------------------------------

/// Prescaler and standby behaviour for the RTC counter.
pub const Config = struct {
    prescaler: Prescaler = .DIV1,
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
    rtc.CTRLA.write(.{
        .RTCEN = 0,
        .CORREN = 0,
        .PRESCALER = config.prescaler,
        .RUNSTDBY = @intFromBool(config.run_standby),
    });

    while (period_busy()) {}
    rtc.PER = config.period;

    while (compare_busy()) {}
    rtc.CMP = config.compare;

    // Enable last so the prescaler/config land together (section 26.4.1.2).
    while (ctrla_busy()) {}
    rtc.CTRLA.modify(.{ .RTCEN = 1 });
}

/// Stop the counter but keep the configuration.
pub fn stop() void {
    while (ctrla_busy()) {}
    rtc.CTRLA.modify(.{ .RTCEN = 0 });
}

/// Read the counter (waits out any pending sync).
pub fn count() u16 {
    return rtc.CNT;
}

/// Write the counter; the value lands after synchronization.
pub fn set_count(value: u16) void {
    while (count_busy()) {}
    rtc.CNT = value;
}

/// Set the top value used in periodic mode.
pub fn set_period(value: u16) void {
    while (period_busy()) {}
    rtc.PER = value;
}

/// Set the compare value for the CMP interrupt.
pub fn set_compare(value: u16) void {
    while (compare_busy()) {}
    rtc.CMP = value;
}

/// Interrupt when the counter wraps.
pub fn enable_overflow_interrupt() void {
    rtc.INTCTRL.modify(.{ .OVF = 1 });
}

/// Interrupt when COUNT matches CMP.
pub fn enable_compare_interrupt() void {
    rtc.INTCTRL.modify(.{ .CMP = 1 });
}

/// Mask both RTC interrupt sources.
pub fn disable_interrupts() void {
    rtc.INTCTRL.write(.{ .OVF = 0, .CMP = 0 });
}

/// True when an overflow was seen since the last clear.
pub fn overflow_pending() bool {
    return rtc.INTFLAGS.read().OVF != 0;
}

/// True when a compare match was seen since the last clear.
pub fn compare_pending() bool {
    return rtc.INTFLAGS.read().CMP != 0;
}

/// Clear the overflow flag.
pub fn clear_overflow() void {
    rtc.INTFLAGS.write(.{ .OVF = 1, .CMP = 0 });
}

/// Clear the compare flag.
pub fn clear_compare() void {
    rtc.INTFLAGS.write(.{ .OVF = 0, .CMP = 1 });
}

/// Apply the crystal error correction value in RTC.CALIB and enable
/// correction.
///
/// DS40002413 section 26.6 "Crystal Error Correction", page 350: correction
/// works by inserting or skipping CLK_RTC cycles, so `error_value` is a count
/// (0..127) and `negative` chooses the direction via CALIB.SIGN.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=350
pub fn set_calibration(error_value: u7, negative: bool) void {
    rtc.CALIB.write(.{
        .ERROR = error_value,
        .SIGN = @intFromBool(negative),
    });
    while (ctrla_busy()) {}
    rtc.CTRLA.modify(.{ .CORREN = 1 });
}

// -- Debug -------------------------------------------------------------------
//
// DS40002413 section 26.11 "Debug Operation", page 352.
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=352

/// Keep the RTC counter running while the CPU is halted in debug
/// (DBGCTRL.DBGRUN).
pub fn set_debug_run(enable: bool) void {
    rtc.DBGCTRL.write(.{ .DBGRUN = @intFromBool(enable) });
}

// -- PIT ---------------------------------------------------------------------

/// Periodic Interrupt Timer.
///
/// DS40002413 section 26.5 "PIT Functional Description", page 349.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=349
pub const pit = struct {
    /// PITCTRLA.PERIOD, in CLK_RTC cycles. Encodings re-exported from the
    /// generated layer. At the usual 32.768 kHz these run from ~122 us
    /// (`CYC4`) to 1 s (`CYC32768`).
    pub const Period = gen.RTC_PERIOD;

    /// Number of CLK_RTC cycles between ticks. Encoding n maps to
    /// 4 * 2^(n-1), i.e. 1 << (n + 1); OFF gives zero.
    pub fn cycles(p: Period) u16 {
        return switch (p) {
            .OFF => 0,
            else => @as(u16, 1) << @intCast(@backingInt(p) + 1),
        };
    }

    /// Start the PIT.
    ///
    /// DS40002413 section 26.5.2.1 "Enabling and Disabling", page 349:
    /// PITCTRLA is synchronized like the RTC's CTRLA, so wait out
    /// PITSTATUS.CTRLBUSY first or the write is dropped.
    pub fn configure(period: Period, interrupt: bool) void {
        while (busy()) {}
        rtc.PITCTRLA.write(.{
            .PITEN = 1,
            .PERIOD = period,
        });
        rtc.PITINTCTRL.write(.{ .PI = @intFromBool(interrupt) });
    }

    pub fn stop() void {
        while (busy()) {}
        rtc.PITCTRLA.write(.{ .PITEN = 0, .PERIOD = .OFF });
    }

    pub fn busy() bool {
        return rtc.PITSTATUS.read().CTRLBUSY != 0;
    }

    pub fn pending() bool {
        return rtc.PITINTFLAGS.read().PI != 0;
    }

    pub fn clear_interrupt() void {
        rtc.PITINTFLAGS.write(.{ .PI = 1 });
    }

    /// Keep the PIT running while the CPU is halted in debug
    /// (PITDBGCTRL.DBGRUN). Independent of the RTC counter's DBGCTRL.
    pub fn set_debug_run(enable: bool) void {
        rtc.PITDBGCTRL.write(.{ .DBGRUN = @intFromBool(enable) });
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
