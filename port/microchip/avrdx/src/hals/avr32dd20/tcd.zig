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

const microzig = @import("microzig");

const tcd = microzig.chip.peripherals.TCD0;
const gen = microzig.chip.types.peripherals.TCD;

/// CTRLA.CLKSEL. Encodings re-exported from the generated layer.
pub const ClockSource = gen.TCD_CLKSEL;

/// CTRLA.SYNCPRES. Divides the selected clock before it reaches the
/// synchronizer.
pub const SyncPrescaler = gen.TCD_SYNCPRES;

/// CTRLA.CNTPRES. Divides the synchronized clock to make the counter clock.
pub const CounterPrescaler = gen.TCD_CNTPRES;

/// CTRLB.WGMODE.
///
/// DS40002413 section 25.3.3.1 "Waveform Generation Modes", page 299.
pub const Waveform = gen.TCD_WGMODE;

const StatusBits = @TypeOf(tcd.STATUS.read());
const CtrlABits = @TypeOf(tcd.CTRLA.read());
const CtrlBBits = @TypeOf(tcd.CTRLB.read());
const CtrlCBits = @TypeOf(tcd.CTRLC.read());
const CtrlDBits = @TypeOf(tcd.CTRLD.read());
const CtrlEBits = @TypeOf(tcd.CTRLE.read());

/// TCD0 setup; compare values are in counter ticks of the 12-bit ramp.
pub const Config = struct {
    clock: ClockSource = .CLKPER,
    sync_prescaler: SyncPrescaler = .DIV1,
    counter_prescaler: CounterPrescaler = .DIV1,
    waveform: Waveform = .ONERAMP,
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
    return tcd.STATUS.read().ENRDY != 0;
}

/// True when a CTRLE command may be issued.
pub fn command_ready() bool {
    return tcd.STATUS.read().CMDRDY != 0;
}

/// Configure and start TCD0.
///
/// DS40002413 section 25.3.2 "Initialization", page 299: the compare registers
/// are only writable while the timer is disabled, and ENABLE must not be
/// written until STATUS.ENRDY reads 1 -- writing it early is ignored, which
/// presents as a timer that silently never starts.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=299
pub fn configure(config: Config) void {
    disable();

    tcd.CTRLB.write(.{ .WGMODE = config.waveform });

    tcd.CTRLC.write(.{
        .CMPOVR = 0,
        .AUPDATE = @intFromBool(config.auto_update),
        .FIFTY = @intFromBool(config.fifty_percent),
        .CMPCSEL = .PWMA,
        .CMPDSEL = .PWMA,
    });

    tcd.CMPASET.modify(.{ .CMPASET = config.compare_a_set });
    tcd.CMPACLR.modify(.{ .CMPACLR = config.compare_a_clear });
    tcd.CMPBSET.modify(.{ .CMPBSET = config.compare_b_set });
    tcd.CMPBCLR.modify(.{ .COMPBCLR = config.compare_b_clear });

    const ctrla: CtrlABits = .{
        .ENABLE = 0,
        .SYNCPRES = config.sync_prescaler,
        .CNTPRES = config.counter_prescaler,
        .CLKSEL = config.clock,
    };
    tcd.CTRLA.write(ctrla);

    while (!enable_ready()) {}
    tcd.CTRLA.modify(.{ .ENABLE = 1 });
}

/// Stop the timer, waiting for the synchronization handshake first.
pub fn disable() void {
    while (!enable_ready()) {}
    tcd.CTRLA.modify(.{ .ENABLE = 0 });
    while (!enable_ready()) {}
}

/// Stop at the end of the current PWM cycle rather than immediately, so the
/// outputs are not cut off mid-pulse.
pub fn disable_at_end_of_cycle() void {
    while (!command_ready()) {}
    tcd.CTRLE.write(.{ .SYNCEOC = 0, .SYNC = 0, .RESTART = 0, .SCAPTUREA = 0, .SCAPTUREB = 0, .DISEOC = 1 });
}

/// Push buffered compare values into the running timer now.
///
/// Not needed when `Config.auto_update` is set.
pub fn synchronize() void {
    while (!command_ready()) {}
    tcd.CTRLE.write(.{ .SYNCEOC = 0, .SYNC = 1, .RESTART = 0, .SCAPTUREA = 0, .SCAPTUREB = 0, .DISEOC = 0 });
}

/// Push buffered values at the end of the current cycle.
pub fn synchronize_at_end_of_cycle() void {
    while (!command_ready()) {}
    tcd.CTRLE.write(.{ .SYNCEOC = 1, .SYNC = 0, .RESTART = 0, .SCAPTUREA = 0, .SCAPTUREB = 0, .DISEOC = 0 });
}

/// Force the ramp back to its start on the next cycle boundary.
pub fn restart() void {
    while (!command_ready()) {}
    tcd.CTRLE.write(.{ .SYNCEOC = 0, .SYNC = 0, .RESTART = 1, .SCAPTUREA = 0, .SCAPTUREB = 0, .DISEOC = 0 });
}

/// Update channel A edges (double-buffered; lands on SYNC/AUPDATE).
pub fn set_compare_a(set_value: u12, clear_value: u12) void {
    tcd.CMPASET.modify(.{ .CMPASET = set_value });
    tcd.CMPACLR.modify(.{ .CMPACLR = clear_value });
}

/// Update channel B edges (double-buffered; lands on SYNC/AUPDATE).
pub fn set_compare_b(set_value: u12, clear_value: u12) void {
    tcd.CMPBSET.modify(.{ .CMPBSET = set_value });
    tcd.CMPBCLR.modify(.{ .COMPBCLR = clear_value });
}

/// Take direct control of the waveform outputs (CTRLC.CMPOVR with the CTRLD
/// compare values), which is how the outputs are parked in a safe state.
pub fn override_outputs(a_high: bool, b_high: bool) void {
    // CTRLD.A/B are four-bit output override values per channel pair.
    tcd.CTRLD.write(.{
        .CMPAVAL = if (a_high) 0xF else 0x0,
        .CMPBVAL = if (b_high) 0xF else 0x0,
    });
    tcd.CTRLC.modify(.{ .CMPOVR = 1 });
}

/// Hand the outputs back to the waveform generator (CMPOVR = 0).
pub fn release_outputs() void {
    tcd.CTRLC.modify(.{ .CMPOVR = 0 });
}

/// Raw FAULTCTRL value.
///
/// FAULTCTRL is loaded from fuses at reset and is CCP-protected (section
/// 25.3.8, page 321), so a change at run time is unusual; this exposes the raw
/// value for the cases that need it. The CMPA/CMPB polarity rule that applies
/// when override is combined with fault detection is documented in section
/// 25.3.3.7 "Output Control", page 318.
pub fn output_enable_mask() u8 {
    return tcd.FAULTCTRL.raw;
}

/// Interrupt once per completed PWM cycle.
pub fn enable_overflow_interrupt() void {
    tcd.INTCTRL.modify(.{ .OVF = 1 });
}

/// True when a cycle finished since the last clear.
pub fn overflow_pending() bool {
    return tcd.INTFLAGS.read().OVF != 0;
}

/// Clear the overflow flag.
pub fn clear_overflow() void {
    tcd.INTFLAGS.write(.{ .OVF = 1, .TRIGA = 0, .TRIGB = 0 });
}

// -- Event inputs, capture, delay and interrupts ------------------------------
//
// The two event inputs A/B are the TCD's fault and capture backbone: each can
// trigger a fault (override the outputs through INPUTMODEx), a synchronized
// counter capture, or both. Because the counter runs asynchronously to
// CLK_PER, captured values and event actions are all synchronized through the
// CLK_TCD_SYNC domain -- which is why every command below waits on STATUS
// bits instead of assuming immediate effect.

/// Which of the two event inputs to act on.
pub const EventInput = enum(u1) {
    a = 0,
    b = 1,

    pub fn evctrl(e: EventInput) []const u8 {
        return switch (e) {
            .a => "EVCTRLA",
            .b => "EVCTRLB",
        };
    }
    pub fn inputctrl(e: EventInput) []const u8 {
        return switch (e) {
            .a => "INPUTCTRLA",
            .b => "INPUTCTRLB",
        };
    }
};

/// What an enabled event input does.
///
/// DS40002413 section 25.3.3.4 "TCD Inputs", page 306: inputs are fault
/// detection by default; setting ACTION=.CAPTURE turns them into capture
/// triggers instead (and requires INPUTMODE disabled).
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=306
pub const EventAction = gen.TCD_ACTION;

/// EVCTRLx.EDGE - which edge arms the input.
pub const Edge = gen.TCD_EDGE;

/// EVCTRLx.CFG - noise filter vs asynchronous qualification. Filter and ASYNC
/// are mutually exclusive (section 25.3.3.4.2/.3, page 307): any pulse shorter
/// than four counter clocks is filtered out with .FILTER, while .ASYNC gives
/// direct output override without waiting for synchronization.
pub const EventConfig = gen.TCD_CFG;

/// INPUTCTRLx.INPUTMODE - what a detected fault does to the outputs and the
/// ramp; only some modes are valid in each waveform mode (Table 25-5,
/// section 25.3.3.4.5, page 307). `.NONE` turns fault detection off so the
/// input can serve purely as a capture trigger.
pub const InputMode = gen.TCD_INPUTMODE;

/// Configure one of the two event inputs.
pub fn configure_event_input(comptime input: EventInput, options: struct {
    /// EVCTRLx.TRIGEI - enable the input at all.
    enable: bool = true,
    action: EventAction = .FAULT,
    edge: Edge = .FALL_LOW,
    cfg: EventConfig = .NEITHER,
    /// INPUTCTRLx.INPUTMODE - the action taken when a fault is seen.
    input_mode: InputMode = .NONE,
}) void {
    @field(tcd, input.evctrl()).write(.{
        .TRIGEI = @intFromBool(options.enable),
        .ACTION = options.action,
        .EDGE = options.edge,
        .CFG = options.cfg,
    });
    @field(tcd, input.inputctrl()).write(.{ .INPUTMODE = options.input_mode });
}

/// Disable both the event trigger and fault handling of an input.
pub fn disable_event_input(comptime input: EventInput) void {
    configure_event_input(input, .{ .enable = false });
}

// -- Delay / dead time --------------------------------------------------------

/// DLYCTRL.DLYSEL - what the delay unit is used for: nothing, masking input
/// events right after output changes ("input blanking"), or delaying the
/// programmable output event. Blanking and output events share one unit, so
/// only one can be active (section 25.3.3.4.1 "Input Blanking", page 307).
pub const DelaySelect = gen.TCD_DLYSEL;

/// DLYCTRL.DLYTRIG - which ramp edge starts the blanking/delay window.
pub const DelayTrigger = gen.TCD_DLYTRIG;

/// DLYCTRL.DLYPRESC - prescales the synchronizer clock for DLYVAL counting.
pub const DelayPrescaler = gen.TCD_DLYPRESC;

/// Configure the delay unit.
///
/// With `select = .INBLANK`, input events are ignored for
/// `t_BLANK = DLYPRESC_factor * value / f_CLK_TCD_SYNC` after the selected
/// trigger edge -- the standard fix for current-sensing spikes caused by the
/// PWM edge itself.
///
/// DS40002413 section 25.3.3.4.1 "Input Blanking", page 307.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=307
pub fn configure_delay(options: struct {
    select: DelaySelect,
    trigger: DelayTrigger,
    prescaler: DelayPrescaler = .DIV1,
    value: u8 = 0,
}) void {
    tcd.DLYCTRL.write(.{
        .DLYSEL = options.select,
        .DLYTRIG = options.trigger,
        .DLYPRESC = options.prescaler,
    });
    tcd.DLYVAL.write(.{ .DLYVAL = options.value });
}

// -- Capture ------------------------------------------------------------------

/// Capture the live counter value under software control.
///
/// DS40002413 section 25.3.3.6 "TCD Counter Capture", page 316: strobe
/// SCAPTUREx via CTRLE, wait for CMDRDY again, then read CAPTUREA/B. The
/// register file holds the low byte first in hardware order, which the
/// generated u16 read performs as two byte loads.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=316
pub fn capture_counter(comptime input: EventInput) u12 {
    const bits = CtrlEBits{
        .SYNCEOC = 0,
        .SYNC = 0,
        .RESTART = 0,
        .SCAPTUREA = @intFromBool(input == .a),
        .SCAPTUREB = @intFromBool(input == .b),
        .DISEOC = 0,
    };
    while (!command_ready()) {}
    tcd.CTRLE.write(bits);
    while (!command_ready()) {}
    return switch (input) {
        .a => tcd.CAPTUREA.read().CAPTUREA,
        .b => tcd.CAPTUREB.read().CAPTUREB,
    };
}

/// Last value captured by input event or software strobe.
pub fn last_capture(comptime input: EventInput) u12 {
    return switch (input) {
        .a => tcd.CAPTUREA.read().CAPTUREA,
        .b => tcd.CAPTUREB.read().CAPTUREB,
    };
}

// -- Interrupts ---------------------------------------------------------------

/// One of the three TCD interrupt sources.
pub const Source = enum(u2) {
    /// One PWM cycle finished (INTFLAGS.OVF).
    overflow = 0,
    /// Input/capture A fired (INTFLAGS.TRIGA).
    trig_a = 1,
    /// Input/capture B fired (INTFLAGS.TRIGB).
    trig_b = 2,

    pub fn field(s: Source) []const u8 {
        return switch (s) {
            .overflow => "OVF",
            .trig_a => "TRIGA",
            .trig_b => "TRIGB",
        };
    }
};

/// Enable one interrupt source.
///
/// DS40002413 section 25.3.5 "Interrupts", page 320: OVF fires when a TCD
/// cycle completes; TRIGA/TRIGB when that input captures (ACTION=.CAPTURE) or,
/// with input modes active, when the fault/restart action triggers.
pub fn enable_interrupt(comptime source: Source) void {
    var ctrl = tcd.INTCTRL.read();
    @field(ctrl, source.field()) = 1;
    tcd.INTCTRL.write(ctrl);
}

/// Mask one interrupt source.
pub fn disable_interrupt(comptime source: Source) void {
    var ctrl = tcd.INTCTRL.read();
    @field(ctrl, source.field()) = 0;
    tcd.INTCTRL.write(ctrl);
}

/// True when this source's flag is raised.
pub fn interrupt_pending(comptime source: Source) bool {
    return @field(tcd.INTFLAGS.read(), source.field()) != 0;
}

/// Clear one interrupt flag (write-one-to-clear; other flags untouched).
pub fn clear_interrupt_flag(comptime source: Source) void {
    const flags: @TypeOf(tcd.INTFLAGS.read()) = switch (source) {
        .overflow => .{ .OVF = 1, .TRIGA = 0, .TRIGB = 0 },
        .trig_a => .{ .OVF = 0, .TRIGA = 1, .TRIGB = 0 },
        .trig_b => .{ .OVF = 0, .TRIGA = 0, .TRIGB = 1 },
    };
    tcd.INTFLAGS.write(flags);
}

// -- Status extras ------------------------------------------------------------

/// Live PWM activity flags (STATUS.PWMACTA/B): true while WOA/WOB is in its
/// on-time. Useful for sequencing external circuitry around the PWM edges.
pub fn pwm_activity() struct { a: bool, b: bool } {
    const s = tcd.STATUS.read();
    return .{ .a = s.PWMACTA != 0, .b = s.PWMACTB != 0 };
}
