//! TCD0 - 12-bit Timer/Counter Type D.
//!
//! DS40002413 section 25 "TCD - 12-Bit Timer/Counter Type D", page 296.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=296
//!
//! TCD is the asynchronous timer: it can run from a clock faster than
//! CLK_PER (the PLL, or OSCHF directly), which is what makes high-resolution
//! PWM and hardware dead-time insertion possible. That asynchrony is also why
//! it is fussier than TCA and TCB -- most registers are double-buffered across
//! a clock domain and need an explicit synchronization strobe, and ENABLE
//! itself can only be changed when STATUS.ENRDY is set.

const regs = @import("registers.zig");

/// CTRLA.CLKSEL, bits 6:5.
pub const ClockSource = enum(u8) {
    /// Internal high-frequency oscillator, independent of CLK_PER.
    oschf = 0x0,
    /// The PLL output -- the reason to use TCD for fine-grained PWM.
    pll = 0x1,
    external = 0x2,
    clk_per = 0x3,
};

/// CTRLA.SYNCPRES, bits 2:1. Divides the selected clock before it reaches the
/// synchronizer.
pub const SyncPrescaler = enum(u8) {
    div1 = 0x0,
    div2 = 0x1,
    div4 = 0x2,
    div8 = 0x3,
};

/// CTRLA.CNTPRES, bits 4:3. Divides the synchronized clock to make the counter
/// clock.
pub const CounterPrescaler = enum(u8) {
    div1 = 0x0,
    div4 = 0x1,
    div32 = 0x2,
};

/// CTRLB.WGMODE.
///
/// DS40002413 section 25.3.3.1 "Waveform Generation Modes", page 299.
pub const Waveform = enum(u8) {
    /// One ramp: a single counter sweep drives both outputs, with WOA's pulse
    /// set by CMPASET/CMPACLR and WOB's by CMPBSET/CMPBCLR. The usual choice
    /// for complementary drive with dead time.
    one_ramp = 0x0,
    two_ramp = 0x1,
    four_ramp = 0x2,
    dual_slope = 0x3,
};

pub const Config = struct {
    clock: ClockSource = .clk_per,
    sync_prescaler: SyncPrescaler = .div1,
    counter_prescaler: CounterPrescaler = .div1,
    waveform: Waveform = .one_ramp,
    /// Channel A rising and falling edge positions, in counter ticks.
    compare_a_set: u12 = 0,
    compare_a_clear: u12 = 0,
    /// Channel B rising and falling edge positions.
    compare_b_set: u12 = 0,
    compare_b_clear: u12 = 0,
    /// CTRLC.AUPDATE - reload the compare buffers automatically at the end of
    /// each cycle instead of waiting for a `synchronize()`.
    auto_update: bool = true,
    /// CTRLC.FIFTY - force a 50% duty cycle, which frees CMPBSET/CMPBCLR to be
    /// used purely as dead time.
    fifty_percent: bool = false,
};

/// True when ENABLE may be written.
pub fn enable_ready() bool {
    return (regs.read(regs.tcd0.status) & regs.bit(regs.tcd0.enrdy)) != 0;
}

/// True when a CTRLE command may be issued.
pub fn command_ready() bool {
    return (regs.read(regs.tcd0.status) & regs.bit(regs.tcd0.cmdrdy)) != 0;
}

/// Configure and start TCD0.
///
/// DS40002413 section 25.3.2 "Initialization", page 298: the compare registers
/// are only writable while the timer is disabled, and ENABLE must not be
/// written until STATUS.ENRDY reads 1 -- writing it early is ignored, which
/// presents as a timer that silently never starts.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=298
pub fn configure(config: Config) void {
    disable();

    regs.write(regs.tcd0.ctrlb, @intFromEnum(config.waveform));

    var ctrlc: u8 = 0;
    if (config.auto_update) ctrlc |= regs.bit(1);
    if (config.fifty_percent) ctrlc |= regs.bit(3);
    regs.write(regs.tcd0.ctrlc, ctrlc);

    regs.mem16(regs.tcd0.cmpaset).* = config.compare_a_set;
    regs.mem16(regs.tcd0.cmpaclr).* = config.compare_a_clear;
    regs.mem16(regs.tcd0.cmpbset).* = config.compare_b_set;
    regs.mem16(regs.tcd0.cmpbclr).* = config.compare_b_clear;

    const ctrla: u8 = (@as(u8, @intFromEnum(config.clock)) << 5) |
        (@as(u8, @intFromEnum(config.counter_prescaler)) << 3) |
        (@as(u8, @intFromEnum(config.sync_prescaler)) << 1);
    regs.write(regs.tcd0.ctrla, ctrla);

    while (!enable_ready()) {}
    regs.set_bits(regs.tcd0.ctrla, regs.bit(regs.tcd0.enable));
}

/// Stop the timer, waiting for the synchronization handshake first.
pub fn disable() void {
    while (!enable_ready()) {}
    regs.clear_bits(regs.tcd0.ctrla, regs.bit(regs.tcd0.enable));
    while (!enable_ready()) {}
}

/// Stop at the end of the current PWM cycle rather than immediately, so the
/// outputs are not cut off mid-pulse.
pub fn disable_at_end_of_cycle() void {
    while (!command_ready()) {}
    regs.write(regs.tcd0.ctrle, regs.bit(regs.tcd0.disable));
}

/// Push buffered compare values into the running timer now.
///
/// Not needed when `Config.auto_update` is set.
pub fn synchronize() void {
    while (!command_ready()) {}
    regs.write(regs.tcd0.ctrle, regs.bit(regs.tcd0.sync));
}

/// Push buffered values at the end of the current cycle.
pub fn synchronize_at_end_of_cycle() void {
    while (!command_ready()) {}
    regs.write(regs.tcd0.ctrle, regs.bit(regs.tcd0.synceoc));
}

pub fn restart() void {
    while (!command_ready()) {}
    regs.write(regs.tcd0.ctrle, regs.bit(regs.tcd0.restart));
}

pub fn set_compare_a(set_value: u12, clear_value: u12) void {
    regs.mem16(regs.tcd0.cmpaset).* = set_value;
    regs.mem16(regs.tcd0.cmpaclr).* = clear_value;
}

pub fn set_compare_b(set_value: u12, clear_value: u12) void {
    regs.mem16(regs.tcd0.cmpbset).* = set_value;
    regs.mem16(regs.tcd0.cmpbclr).* = clear_value;
}

/// Take direct control of the waveform outputs (CTRLC.CMPOVR with the
/// CTRLD compare values), which is how the outputs are parked in a safe state.
pub fn override_outputs(a_high: bool, b_high: bool) void {
    regs.write(
        regs.tcd0.ctrld,
        (if (a_high) @as(u8, 0x0F) else 0) | (if (b_high) @as(u8, 0xF0) else 0),
    );
    regs.set_bits(regs.tcd0.ctrlc, regs.bit(0));
}

pub fn release_outputs() void {
    regs.clear_bits(regs.tcd0.ctrlc, regs.bit(0));
}

/// Enable the fault/blanking inputs on the waveform outputs.
///
/// FAULTCTRL is loaded from fuses at reset and is CCP-protected, so a change
/// at run time is unusual; this exposes the raw value for the cases that need
/// it. DS40002413 section 25.3.3.5 "Fault Control", page 307.
pub fn output_enable_mask() u8 {
    return regs.read(regs.tcd0.faultctrl);
}

pub fn enable_overflow_interrupt() void {
    regs.set_bits(regs.tcd0.intctrl, regs.bit(regs.tcd0.ovf));
}

pub fn overflow_pending() bool {
    return (regs.read(regs.tcd0.intflags) & regs.bit(regs.tcd0.ovf)) != 0;
}

pub fn clear_overflow() void {
    regs.write(regs.tcd0.intflags, regs.bit(regs.tcd0.ovf));
}
