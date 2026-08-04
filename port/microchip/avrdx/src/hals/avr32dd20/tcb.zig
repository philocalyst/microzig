//! TCB0 / TCB1 - 16-bit Timer/Counter Type B.
//!
//! DS40002413 section 24 "TCB - 16-Bit Timer/Counter Type B", page 272.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=272
//!
//! Both instances are identical, so this module is parameterized by instance
//! rather than duplicated. `Tcb.tcb0` / `Tcb.tcb1` name them.

const regs = @import("registers.zig");

/// CTRLA.CLKSEL, bits 3:1.
pub const ClockSelect = enum(u8) {
    div1 = 0x0,
    div2 = 0x1,
    /// Reuse TCA0's prescaled clock, which keeps the two timers in step.
    tca0 = 0x2,
    /// Count edges on the timer's event input instead of a clock.
    event = 0x7,
};

/// CTRLB.CNTMODE, bits 2:0.
///
/// DS40002413 section 24.3.3.1 "Modes", page 275.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=275
pub const CountMode = enum(u8) {
    /// Count to CCMP, raise CAPT, restart. The plain periodic tick.
    periodic_interrupt = 0x0,
    /// Count to CCMP and stop, raising CAPT. A software-armed timeout.
    periodic_timeout = 0x1,
    /// Capture CNT into CCMP on the event edge.
    input_capture = 0x2,
    /// Measure the period between two identical event edges.
    frequency_measurement = 0x3,
    /// Measure the width of an event pulse.
    pulse_width_measurement = 0x4,
    /// Both of the above, alternating.
    frequency_and_pulse_width = 0x5,
    /// One output pulse per event edge, length set by CCMP.
    single_shot = 0x6,
    /// Two 8-bit halves of CCMP become period and duty for an 8-bit PWM.
    /// Section 24.3.3.1.8, page 280.
    pwm8 = 0x7,
};

pub const Config = struct {
    mode: CountMode = .periodic_interrupt,
    clock: ClockSelect = .div1,
    /// Compare/capture value. In `pwm8` the low byte is the period and the
    /// high byte the duty cycle.
    compare: u16 = 0,
    /// CTRLB.CCMPEN: drive the waveform output pin. Route it first with
    /// `portmux.set_tcb0_output` / `set_tcb1_output`.
    enable_output: bool = false,
    /// CTRLB.CCMPINIT: initial level of the output pin.
    output_initial_high: bool = false,
    /// CTRLB.ASYNC: in single-shot mode, let the event start the output pulse
    /// directly instead of waiting for the next counter tick.
    asynchronous: bool = false,
    /// CTRLA.RUNSTDBY.
    run_standby: bool = false,
    /// EVCTRL.CAPTEI: let the event channel drive capture/start.
    enable_event_input: bool = false,
    /// EVCTRL.EDGE: act on the falling edge instead of the rising one.
    event_falling_edge: bool = false,
    /// EVCTRL.FILTER: four-sample noise canceler on the event input.
    /// Section 24.3.3.4 "Noise Canceler", page 282.
    noise_filter: bool = false,
};

pub const Tcb = struct {
    base: u16,

    /// Waveform output on PA2 (see `portmux.set_tcb0_output`).
    pub const tcb0: Tcb = .{ .base = regs.tcb0_base };
    /// Waveform output on PA3 (see `portmux.set_tcb1_output`).
    pub const tcb1: Tcb = .{ .base = regs.tcb1_base };

    fn reg(t: Tcb, offset: u16) u16 {
        return t.base + offset;
    }

    /// Configure and start the timer.
    pub fn configure(t: Tcb, config: Config) void {
        regs.write(t.reg(regs.tcb_offsets.ctrla), 0);

        var ctrlb: u8 = @intFromEnum(config.mode);
        if (config.enable_output) ctrlb |= regs.bit(regs.tcb_bits.ccmpen);
        if (config.output_initial_high) ctrlb |= regs.bit(regs.tcb_bits.ccmpinit);
        if (config.asynchronous) ctrlb |= regs.bit(regs.tcb_bits.asyncen);
        regs.write(t.reg(regs.tcb_offsets.ctrlb), ctrlb);

        var evctrl: u8 = 0;
        if (config.enable_event_input) evctrl |= regs.bit(0);
        if (config.event_falling_edge) evctrl |= regs.bit(4);
        if (config.noise_filter) evctrl |= regs.bit(6);
        regs.write(t.reg(regs.tcb_offsets.evctrl), evctrl);

        regs.mem16(t.reg(regs.tcb_offsets.ccmp)).* = config.compare;

        var ctrla: u8 = (@as(u8, @intFromEnum(config.clock)) << 1) | regs.bit(regs.tcb_bits.enable);
        if (config.run_standby) ctrla |= regs.bit(regs.tcb_bits.runstdby);
        regs.write(t.reg(regs.tcb_offsets.ctrla), ctrla);
    }

    pub fn start(t: Tcb) void {
        regs.set_bits(t.reg(regs.tcb_offsets.ctrla), regs.bit(regs.tcb_bits.enable));
    }

    pub fn stop(t: Tcb) void {
        regs.clear_bits(t.reg(regs.tcb_offsets.ctrla), regs.bit(regs.tcb_bits.enable));
    }

    /// True while the counter is actually running. In single-shot mode this
    /// distinguishes "armed" from "pulsing".
    pub fn running(t: Tcb) bool {
        return (regs.read(t.reg(regs.tcb_offsets.status)) & regs.bit(regs.tcb_bits.run)) != 0;
    }

    pub fn counter(t: Tcb) u16 {
        return regs.mem16(t.reg(regs.tcb_offsets.cnt)).*;
    }

    pub fn set_counter(t: Tcb, value: u16) void {
        regs.mem16(t.reg(regs.tcb_offsets.cnt)).* = value;
    }

    pub fn compare(t: Tcb) u16 {
        return regs.mem16(t.reg(regs.tcb_offsets.ccmp)).*;
    }

    pub fn set_compare(t: Tcb, value: u16) void {
        regs.mem16(t.reg(regs.tcb_offsets.ccmp)).* = value;
    }

    /// Set period and duty for `pwm8` mode, where CCMP packs both bytes.
    pub fn set_pwm8(t: Tcb, period: u8, duty: u8) void {
        regs.mem16(t.reg(regs.tcb_offsets.ccmp)).* =
            @as(u16, period) | (@as(u16, duty) << 8);
    }

    /// Take a captured value and clear CAPT in one step.
    ///
    /// DS40002413 section 24.3.3.1.3 "Input Capture on Event Mode", page 276:
    /// reading CCMP is what releases the capture register for the next event,
    /// so a handler that only clears the flag will miss captures.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=276
    pub fn take_capture(t: Tcb) u16 {
        const value = regs.mem16(t.reg(regs.tcb_offsets.ccmp)).*;
        regs.write(t.reg(regs.tcb_offsets.intflags), regs.bit(regs.tcb_bits.capt));
        return value;
    }

    pub fn enable_capture_interrupt(t: Tcb) void {
        regs.set_bits(t.reg(regs.tcb_offsets.intctrl), regs.bit(regs.tcb_bits.capt));
    }

    pub fn enable_overflow_interrupt(t: Tcb) void {
        regs.set_bits(t.reg(regs.tcb_offsets.intctrl), regs.bit(regs.tcb_bits.ovf));
    }

    pub fn disable_interrupts(t: Tcb) void {
        regs.write(t.reg(regs.tcb_offsets.intctrl), 0);
    }

    pub fn capture_pending(t: Tcb) bool {
        return (regs.read(t.reg(regs.tcb_offsets.intflags)) & regs.bit(regs.tcb_bits.capt)) != 0;
    }

    pub fn clear_capture(t: Tcb) void {
        regs.write(t.reg(regs.tcb_offsets.intflags), regs.bit(regs.tcb_bits.capt));
    }

    pub fn overflow_pending(t: Tcb) bool {
        return (regs.read(t.reg(regs.tcb_offsets.intflags)) & regs.bit(regs.tcb_bits.ovf)) != 0;
    }

    pub fn clear_overflow(t: Tcb) void {
        regs.write(t.reg(regs.tcb_offsets.intflags), regs.bit(regs.tcb_bits.ovf));
    }

    /// Chain TCB1 onto TCB0 for a 32-bit capture.
    ///
    /// DS40002413 section 24.3.3.3 "32-Bit Input Capture", page 281: the upper
    /// timer sets CTRLA.CASCADE and counts the lower timer's overflows. Call
    /// this on the *upper* instance (TCB1).
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=281
    pub fn set_cascade(t: Tcb, enable: bool) void {
        const address = t.reg(regs.tcb_offsets.ctrla);
        if (enable) {
            regs.set_bits(address, regs.bit(regs.tcb_bits.cascade));
        } else {
            regs.clear_bits(address, regs.bit(regs.tcb_bits.cascade));
        }
    }

    /// CTRLA.SYNCUPD: restart this timer whenever TCA0 restarts, so a TCB PWM
    /// stays phase-locked to the TCA one.
    pub fn set_sync_update(t: Tcb, enable: bool) void {
        const address = t.reg(regs.tcb_offsets.ctrla);
        if (enable) {
            regs.set_bits(address, regs.bit(regs.tcb_bits.synupd));
        } else {
            regs.clear_bits(address, regs.bit(regs.tcb_bits.synupd));
        }
    }
};
