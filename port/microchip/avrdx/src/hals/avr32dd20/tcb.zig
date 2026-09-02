//! TCB0 / TCB1 - 16-bit Timer/Counter Type B.
//!
//! DS40002413 section 24 "TCB - 16-Bit Timer/Counter Type B", page 272.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=272
//!
//! Both instances are identical, so this module is parameterized by instance
//! rather than duplicated. `Instance(0)` / `instance0` name them.
//!
//! Waveform outputs: the ATDF gives TCB0 and TCB1 only their DEFAULT routes,
//! WO on PA2 and PA3 respectively; there are no PORTMUX alternatives on this
//! package (the TCBROUTEA bits carry a single defined value each). Enabling
//! the pin is done with CTRLB.CCMPEN, which is what `Config.enable_output`
//! sets -- never by writing the route bits, whose non-default values are
//! reserved.

const microzig = @import("microzig");

const chip = microzig.chip.peripherals;
const types = microzig.chip.types.peripherals.TCB;

/// CTRLA.CLKSEL. Encodings re-exported from the generated layer.
pub const ClockSelect = types.TCB_CLKSEL;

/// CTRLB.CNTMODE. Encodings re-exported from the generated layer.
///
/// DS40002413 section 24.3.3.1 "Modes", page 275.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=275
pub const CountMode = types.TCB_CNTMODE;

fn instance(comptime id: u1) *volatile types.TCB {
    return switch (id) {
        0 => chip.TCB0,
        1 => chip.TCB1,
    };
}

/// One configuration shape for both timers.
pub const Config = struct {
    mode: CountMode = .INT,
    clock: ClockSelect = .DIV1,
    /// Compare/capture value. In `PWM8` the low byte is the period and the
    /// high byte the duty cycle.
    compare: u16 = 0,
    /// CTRLB.CCMPEN: drive the waveform output pin (TCB0 -> PA2, TCB1 -> PA3).
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

/// Build the typed namespace for TCB0 or TCB1.
/// The id is checked against this package's timer count at compile time.
pub fn Instance(comptime id: u1) type {
    return struct {
        const t = instance(id);

        /// Waveform output pin for this instance (PA2 / PA3).
        pub const output_pad: u8 = if (id == 0) 2 else 3;

        /// Configure and start the timer.
        pub fn configure(config: Config) void {
            t.CTRLA.write(.{
                .ENABLE = 0,
                .CLKSEL = config.clock,
                .SYNCUPD = 0,
                .CASCADE = 0,
                .RUNSTDBY = @intFromBool(config.run_standby),
            });

            t.CTRLB.write(.{
                .CNTMODE = config.mode,
                .CCMPINIT = @intFromBool(config.output_initial_high),
                .ASYNC = @intFromBool(config.asynchronous),
                .CCMPEN = @intFromBool(config.enable_output),
            });

            t.EVCTRL.write(.{
                .CAPTEI = @intFromBool(config.enable_event_input),
                .EDGE = @intFromBool(config.event_falling_edge),
                .FILTER = @intFromBool(config.noise_filter),
            });

            t.CCMP = config.compare;

            t.CTRLA.modify(.{ .ENABLE = 1 });
        }

        pub fn start() void {
            t.CTRLA.modify(.{ .ENABLE = 1 });
        }

        pub fn stop() void {
            t.CTRLA.modify(.{ .ENABLE = 0 });
        }

        /// True while the counter is actually running. In single-shot mode
        /// this distinguishes "armed" from "pulsing".
        pub fn running() bool {
            return t.STATUS.read().RUN != 0;
        }

        pub fn counter() u16 {
            return t.CNT;
        }

        pub fn set_counter(value: u16) void {
            t.CNT = value;
        }

        pub fn compare() u16 {
            return t.CCMP;
        }

        pub fn set_compare(value: u16) void {
            t.CCMP = value;
        }

        /// Set period and duty for `PWM8` mode, where CCMP packs both bytes.
        pub fn set_pwm8(period: u8, duty: u8) void {
            t.CCMP = @as(u16, period) | (@as(u16, duty) << 8);
        }

        /// Take a captured value and clear CAPT in one step.
        ///
        /// DS40002413 section 24.3.3.1.3 "Input Capture on Event Mode", page
        /// 276: reading CCMP is what releases the capture register for the
        /// next event, so a handler that only clears the flag will miss
        /// captures.
        /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=276
        pub fn take_capture() u16 {
            const value = t.CCMP;
            t.INTFLAGS.write(.{ .CAPT = 1, .OVF = 0 });
            return value;
        }

        pub fn enable_capture_interrupt() void {
            t.INTCTRL.modify(.{ .CAPT = 1 });
        }

        pub fn enable_overflow_interrupt() void {
            t.INTCTRL.modify(.{ .OVF = 1 });
        }

        pub fn disable_interrupts() void {
            t.INTCTRL.write(.{ .CAPT = 0, .OVF = 0 });
        }

        pub fn capture_pending() bool {
            return t.INTFLAGS.read().CAPT != 0;
        }

        pub fn clear_capture() void {
            t.INTFLAGS.write(.{ .CAPT = 1, .OVF = 0 });
        }

        pub fn overflow_pending() bool {
            return t.INTFLAGS.read().OVF != 0;
        }

        pub fn clear_overflow() void {
            t.INTFLAGS.write(.{ .CAPT = 0, .OVF = 1 });
        }

        /// Chain this timer onto the lower one for a 32-bit capture.
        ///
        /// DS40002413 section 24.3.3.3 "32-Bit Input Capture", page 281: the
        /// upper timer sets CTRLA.CASCADE and counts the lower timer's
        /// overflows. Call this on the *upper* instance (TCB1), with both on
        /// the same clock and the lower one in `TIMEOUT` mode per the
        /// datasheet's cascade recipe.
        /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=281
        pub fn set_cascade(enable: bool) void {
            comptime if (id != 1)
                @compileError("cascade makes only the upper timer (TCB1) count lower-timer overflows");
            t.CTRLA.modify(.{ .CASCADE = @intFromBool(enable) });
        }

        /// CTRLA.SYNCUPD: restart this timer whenever TCA0 restarts, so a TCB
        /// PWM stays phase-locked to the TCA one.
        pub fn set_sync_update(enable: bool) void {
            t.CTRLA.modify(.{ .SYNCUPD = @intFromBool(enable) });
        }
    };
}

/// The TCB0 driver instance.
pub const instance0 = Instance(0);
/// The TCB1 driver instance.
pub const instance1 = Instance(1);
