//! ADC0 - 12-bit Analog-to-Digital Converter.
//!
//! DS40002413 section 33 "ADC - Analog-to-Digital Converter", page 491.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=491
//!
//! This is the AVR Dx ADC, not the 10-bit one from tinyAVR/megaAVR-0: it is
//! 12-bit, has a differential mode, a hardware accumulator and a window
//! comparator, and takes its reference from `VREF.ADC0REF` rather than
//! `VREF.CTRLA`.
//!
//! The channel numbering is sparse, and -- easily overlooked -- the positive
//! and negative muxes accept *different* sets of inputs; see
//! `PositiveChannel` and `NegativeChannel`. Pure arithmetic (averaging with
//! hardware truncation, temperature calibration) lives in `adc_math.zig`,
//! which carries host unit tests.

const std = @import("std");
const microzig = @import("microzig");
const gpio = @import("gpio.zig");
const vref = @import("vref.zig");
const capabilities = @import("capabilities.zig");
/// Accumulation, rescaling and temperature math, unit-tested on the
/// host against DS40002413 tables.
pub const adc_math = @import("adc_math.zig");

const adc = microzig.chip.peripherals.ADC0;
const gen = microzig.chip.types.peripherals.ADC;

/// ADC0.MUXPOS selection, restricted to what exists on this part.
///
/// Encodings match DS40002413B section 33.5.7 "MUX Selection for Positive ADC
/// Input", page 511:
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=511
///
/// The PC channels (AIN29..AIN31) sit on the MVIO port; DS40002413 note 2
/// (peripheral overview) makes them ADC-legal only when MVIO is *disabled*
/// (SYSCFG1.MVSYSCFG = SINGLE) -- see `check_mvio` below.
pub const PositiveChannel = enum(u8) {
    ain4_pd4 = 0x04,
    ain5_pd5 = 0x05,
    ain6_pd6 = 0x06,
    ain7_pd7 = 0x07,
    ain22_pa2 = 0x16,
    ain23_pa3 = 0x17,
    ain24_pa4 = 0x18,
    ain25_pa5 = 0x19,
    ain26_pa6 = 0x1A,
    ain27_pa7 = 0x1B,
    /// PORTC/MVIO pad; legal for ADC only when MVIO is fuse-disabled (SINGLE).
    ain29_pc1 = 0x1D,
    /// PORTC/MVIO pad; legal for ADC only when MVIO is fuse-disabled (SINGLE).
    ain30_pc2 = 0x1E,
    /// PORTC/MVIO pad; legal for ADC only when MVIO is fuse-disabled (SINGLE).
    ain31_pc3 = 0x1F,

    /// Internal ground, for offset measurement.
    ground = 0x40,
    /// On-chip temperature sensor: needs the internal 2.048V reference and
    /// the SIGROW calibration (DS40002413B section 33.3.3.8, page 500).
    temperature = 0x42,
    /// VDD divided by 10.
    vdd_div10 = 0x44,
    /// VDDIO2 (the MVIO supply for PORTC) divided by 10.
    vddio2_div10 = 0x45,
    /// DAC0 output.
    dac0 = 0x48,
    /// The AC0 DAC reference.
    dacref0 = 0x49,

    /// Compile-time MVIO gate for PORTC ADC channels.
    ///
    /// DS40002413 peripheral-overview note 2: ADC inputs on MVIO pins (PORTC)
    /// are available only when MVIO is disabled (FUSE.SYSCFG1.MVSYSCFG =
    /// SINGLE). Dual-supply builds (`capabilities.mvio_enabled_by_fuse`) must
    /// not select AIN29..AIN31.
    ///
    /// Call at comptime for a static choice:
    /// `comptime PositiveChannel.ain29_pc1.check_mvio();`
    /// Runtime selection goes through `assert_mvio_channel_ok`.
    ///
    /// https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-US-8/GUID-F94E51A5-03D0-474D-820B-5DF1CA77A1BD.html
    pub fn check_mvio(self: PositiveChannel) void {
        if (capabilities.mvio_enabled_by_fuse) {
            switch (self) {
                .ain29_pc1, .ain30_pc2, .ain31_pc3 => @compileError("ADC on PORTC (AIN29..AIN31) requires MVSYSCFG=SINGLE; this build has MVIO enabled"),
                else => {},
            }
        }
    }

    /// The GPIO pad this channel measures, or null for internal sources.
    pub fn pin(channel: PositiveChannel) ?gpio.Pin {
        return switch (channel) {
            .ain4_pd4 => gpio.pins.pd4,
            .ain5_pd5 => gpio.pins.pd5,
            .ain6_pd6 => gpio.pins.pd6,
            .ain7_pd7 => gpio.pins.pd7,
            .ain22_pa2 => gpio.pins.pa2,
            .ain23_pa3 => gpio.pins.pa3,
            .ain24_pa4 => gpio.pins.pa4,
            .ain25_pa5 => gpio.pins.pa5,
            .ain26_pa6 => gpio.pins.pa6,
            .ain27_pa7 => gpio.pins.pa7,
            .ain29_pc1 => gpio.pins.pc1,
            .ain30_pc2 => gpio.pins.pc2,
            .ain31_pc3 => gpio.pins.pc3,
            else => null,
        };
    }
};

/// ADC0.MUXNEG selection.
///
/// Deliberately a different type from `PositiveChannel`: per DS40002413B
/// section 33.5.8 "MUX Selection for Negative ADC Input", page 512, the
/// negative mux accepts only AIN pads, GND and DAC0. The extra internal
/// sources offered on the positive side (temperature sensor, VDD/10,
/// VDDIO2/10, DACREF0) do not exist here:
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=512
pub const NegativeChannel = enum(u8) {
    ain4_pd4 = 0x04,
    ain5_pd5 = 0x05,
    ain6_pd6 = 0x06,
    ain7_pd7 = 0x07,
    ain22_pa2 = 0x16,
    ain23_pa3 = 0x17,
    ain24_pa4 = 0x18,
    ain25_pa5 = 0x19,
    ain26_pa6 = 0x1A,
    ain27_pa7 = 0x1B,
    /// PORTC/MVIO pad; legal for ADC only when MVIO is fuse-disabled (SINGLE).
    ain29_pc1 = 0x1D,
    /// PORTC/MVIO pad; legal for ADC only when MVIO is fuse-disabled (SINGLE).
    ain30_pc2 = 0x1E,
    /// PORTC/MVIO pad; legal for ADC only when MVIO is fuse-disabled (SINGLE).
    ain31_pc3 = 0x1F,

    /// Measure against ground: the differential encoding of a single-ended
    /// measurement.
    ground = 0x40,
    /// DAC0 output as the subtracted source.
    dac0 = 0x48,

    /// Same PORTC rule as `PositiveChannel.check_mvio`.
    pub fn check_mvio(self: NegativeChannel) void {
        if (capabilities.mvio_enabled_by_fuse) {
            switch (self) {
                .ain29_pc1, .ain30_pc2, .ain31_pc3 => @compileError("ADC on PORTC (AIN29..AIN31) requires MVSYSCFG=SINGLE; this build has MVIO enabled"),
                else => {},
            }
        }
    }

    /// The GPIO pad this channel measures, or null for internal sources.
    pub fn pin(channel: NegativeChannel) ?gpio.Pin {
        return switch (channel) {
            .ain4_pd4 => gpio.pins.pd4,
            .ain5_pd5 => gpio.pins.pd5,
            .ain6_pd6 => gpio.pins.pd6,
            .ain7_pd7 => gpio.pins.pd7,
            .ain22_pa2 => gpio.pins.pa2,
            .ain23_pa3 => gpio.pins.pa3,
            .ain24_pa4 => gpio.pins.pa4,
            .ain25_pa5 => gpio.pins.pa5,
            .ain26_pa6 => gpio.pins.pa6,
            .ain27_pa7 => gpio.pins.pa7,
            .ain29_pc1 => gpio.pins.pc1,
            .ain30_pc2 => gpio.pins.pc2,
            .ain31_pc3 => gpio.pins.pc3,
            else => null,
        };
    }
};

/// ADC0.CTRLA.RESSEL.
pub const Resolution = gen.ADC_RESSEL;

/// Result ceiling for each resolution, useful for scaling.
pub fn resolution_max(r: Resolution) u16 {
    return switch (r) {
        .@"12BIT" => 4095,
        .@"10BIT" => 1023,
        _ => unreachable,
    };
}

/// ADC0.CTRLA.CONVMODE.
pub const ConversionMode = gen.ADC_CONVMODE;

/// ADC0.CTRLB.SAMPNUM - burst accumulation, re-exported from the generated
/// layer.
///
/// DS40002413B section 33.3.3.6 "Accumulation" plus Tables 33-1/33-2, page
/// 499: RES holds the *sum* of 2^n conversions, and above 16 samples the sum
/// no longer fits in 16 bits so the hardware silently truncates the LSBs.
/// Use the truncation-aware helpers in `adc_math` on raw results.
pub const Accumulation = gen.ADC_SAMPNUM;

/// ADC0.CTRLC.PRESC - CLK_ADC = CLK_PER / divisor, re-exported from the
/// generated layer.
///
/// DS40002413B section 33.3.3.3 "Clock Generation", page 494: keep CLK_ADC
/// inside the electrical characteristics' range (nominally 125 kHz - 2 MHz).
pub const Prescaler = gen.ADC_PRESC;

/// Numeric CLK_PER division factor of a prescaler setting.
pub fn prescaler_divisor(p: Prescaler) u16 {
    return switch (p) {
        // Reserved encodings are treated as DIV2; they cannot be named through
        // this module's API, only forced via @enumFromInt.
        .DIV2 => 2,
        .DIV4 => 4,
        .DIV8 => 8,
        .DIV12 => 12,
        .DIV16 => 16,
        .DIV20 => 20,
        .DIV24 => 24,
        .DIV28 => 28,
        .DIV32 => 32,
        .DIV48 => 48,
        .DIV64 => 64,
        .DIV96 => 96,
        .DIV128 => 128,
        .DIV256 => 256,
        else => 2,
    };
}

/// ADC0.CTRLD.INITDLY - settling delay after enabling the ADC or reference,
/// in CLK_ADC cycles. Re-exported from the generated layer.
pub const InitialDelay = gen.ADC_INITDLY;

/// Smallest INITDLY satisfying ">= N CLK_ADC cycles".
pub fn initial_delay_for_cycles(cycles_needed: u32) InitialDelay {
    return @fromBackingInt(@intCast(adc_math.initial_delay_for_cycles(cycles_needed)));
}

/// ADC0.CTRLD.SAMPDLY - spacing between the samples of an accumulation burst.
pub const SampleDelay = gen.ADC_SAMPDLY;

/// ADC0.CTRLE.WINCM - window comparator mode, re-exported from the generated
/// layer. DS40002413B section 33.3.3.9 "Window Comparator", page 501.
pub const WindowMode = gen.ADC_WINCM;

/// ADC configuration; every field documents its hardware effect.
pub const Config = struct {
    channel: PositiveChannel = .ain22_pa2,
    /// Only used in differential mode. Note the distinct type: the negative
    /// mux takes a different set of inputs.
    negative_channel: NegativeChannel = .ground,
    reference: vref.Reference = .VDD,
    resolution: Resolution = .@"12BIT",
    conversion_mode: ConversionMode = .SINGLEENDED,
    accumulation: Accumulation = .NONE,
    prescaler: Prescaler = .DIV16,
    initial_delay: InitialDelay = .DLY0,
    sample_delay: SampleDelay = .DLY0,
    /// SAMPCTRL.SAMPLEN - extra CLK_ADC cycles of sample time, for sources
    /// with high output impedance.
    sample_length: u8 = 0,
    /// CTRLA.FREERUN - start the next conversion as soon as one finishes.
    free_running: bool = false,
    /// CTRLA.LEFTADJ - left-align the result in the 16-bit register.
    left_adjust: bool = false,
    /// CTRLA.RUNSTBY - keep converting in standby sleep.
    run_standby: bool = false,
    /// EVCTRL.STARTEI - start conversions from an event channel.
    start_on_event: bool = false,
    /// Disable the digital input buffer of the used pin, as the datasheet
    /// requires for analog inputs.
    configure_pin: bool = true,

    /// Comptime rejection of illegal PORTC channels for this build's MVIO fuse.
    pub fn validate(comptime config: Config) void {
        comptime config.channel.check_mvio();
        comptime config.negative_channel.check_mvio();
    }
};

/// Configure and enable the ADC.
///
/// DS40002413B section 33.3.2 "Initialization", page 492: set up the
/// reference and mux before CTRLA.ENABLE, which this ordering does.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=492
pub fn configure(config: Config) void {
    assert_mvio_channel_ok(config.channel);
    assert_mvio_negative_channel_ok(config.negative_channel);

    adc.CTRLA.write(.{
        .ENABLE = 0,
        .FREERUN = 0,
        .RESSEL = config.resolution,
        .LEFTADJ = @intFromBool(config.left_adjust),
        .CONVMODE = config.conversion_mode,
        .RUNSTBY = @intFromBool(config.run_standby),
    });

    vref.set_adc0_reference(config.reference);

    if (config.configure_pin) {
        if (config.channel.pin()) |p| disable_digital_input(p);
        if (config.conversion_mode == .DIFF) {
            if (config.negative_channel.pin()) |p| disable_digital_input(p);
        }
    }

    adc.MUXPOS.write(.{ .MUXPOS = @fromBackingInt(@intCast(@backingInt(config.channel))) });
    adc.MUXNEG.write(.{ .MUXNEG = @fromBackingInt(@intCast(@backingInt(config.negative_channel))) });
    adc.CTRLB.modify(.{ .SAMPNUM = config.accumulation });
    adc.CTRLC.modify(.{ .PRESC = config.prescaler });
    adc.CTRLD.modify(.{
        .SAMPDLY = config.sample_delay,
        .INITDLY = config.initial_delay,
    });
    adc.SAMPCTRL.modify(.{ .SAMPLEN = config.sample_length });
    adc.EVCTRL.modify(.{ .STARTEI = @intFromBool(config.start_on_event) });

    adc.CTRLA.write(.{
        .ENABLE = 1,
        .FREERUN = @intFromBool(config.free_running),
        .RESSEL = config.resolution,
        .LEFTADJ = @intFromBool(config.left_adjust),
        .CONVMODE = config.conversion_mode,
        .RUNSTBY = @intFromBool(config.run_standby),
    });
}

/// Runtime half of the MVIO gate: dual-supply builds
/// (`capabilities.mvio_enabled_by_fuse`) must not select PORTC ADC channels
/// (DS40002413 note 2). Comptime-known choices use `check_mvio` instead.
fn assert_mvio_channel_ok(channel: PositiveChannel) void {
    if (capabilities.mvio_enabled_by_fuse) {
        switch (channel) {
            .ain29_pc1, .ain30_pc2, .ain31_pc3 => @panic("ADC on PORTC (AIN29..AIN31) requires MVSYSCFG=SINGLE; MVIO is enabled in this build"),
            else => {},
        }
    }
}

fn assert_mvio_negative_channel_ok(channel: NegativeChannel) void {
    if (capabilities.mvio_enabled_by_fuse) {
        switch (channel) {
            .ain29_pc1, .ain30_pc2, .ain31_pc3 => @panic("ADC on PORTC (AIN29..AIN31) requires MVSYSCFG=SINGLE; MVIO is enabled in this build"),
            else => {},
        }
    }
}

/// Turn off a pin's digital input buffer, as required for an analog input.
///
/// DS40002413B section 33.3.4 "I/O Lines and Connections", page 501.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=501
pub fn disable_digital_input(p: gpio.Pin) void {
    gpio.set_direction_rt(p, .input);
    gpio.configure_rt(p, .{ .sense = .input_disable });
}

/// Disable the ADC (CTRLA.ENABLE = 0) and stop conversions.
pub fn disable() void {
    adc.CTRLA.modify(.{ .ENABLE = 0 });
}

/// Point the positive mux at a different channel between conversions.
pub fn select_channel(channel: PositiveChannel) void {
    assert_mvio_channel_ok(channel);
    adc.MUXPOS.write(.{ .MUXPOS = @fromBackingInt(@intCast(@backingInt(channel))) });
}

/// Change MUXNEG for differential or window-compared sampling.
pub fn select_negative_channel(channel: NegativeChannel) void {
    assert_mvio_negative_channel_ok(channel);
    adc.MUXNEG.write(.{ .MUXNEG = @fromBackingInt(@intCast(@backingInt(channel))) });
}

/// Start a conversion (COMMAND.STCONV).
pub fn start() void {
    adc.COMMAND.write(.{ .STCONV = 1, .SPCONV = 0 });
}

/// Abort an in-flight conversion, including a free-running sequence.
pub fn stop() void {
    adc.COMMAND.write(.{ .STCONV = 0, .SPCONV = 1 });
}

/// True when a fresh result waits in RES (INTFLAGS.RESRDY).
pub fn result_ready() bool {
    return adc.INTFLAGS.read().RESRDY != 0;
}

/// Raw contents of ADC0.RES.
///
/// DS40002413B section 33.3.3.5 "Conversion Result (Output Formats)", page
/// 497: reading RES clears RESRDY, so handlers need no separate flag clear.
/// With accumulation above 16 samples this value is truncated by the
/// hardware; interpret it through `adc_math`.
pub fn read_raw() u16 {
    return adc.RES;
}

/// Result of a differential conversion, as a signed value.
pub fn read_signed() i16 {
    return @bitCast(read_raw());
}

/// Start one conversion and block until it finishes.
pub fn read_blocking() u16 {
    start();
    while (!result_ready()) {}
    return read_raw();
}

/// Convert one channel, blocking, without disturbing the rest of the setup.
pub fn read_channel_blocking(channel: PositiveChannel) u16 {
    select_channel(channel);
    return read_blocking();
}

/// Average of an accumulated burst, truncation-aware (see `adc_math`).
pub fn average(raw: u16, accumulation: Accumulation) u16 {
    return adc_math.accumulation_average(@backingInt(accumulation), raw);
}

/// Convert a single-ended raw reading to millivolts.
pub fn to_millivolts(raw: u16, reference: vref.Reference, resolution: Resolution) u32 {
    const reference_mv = vref.reference_millivolts(reference) orelse return 0;
    return (@as(u32, raw) * reference_mv) / (@as(u32, resolution_max(resolution)) + 1);
}

// -- Interrupts and window comparator ---------------------------------------

/// Raise the ADC interrupt on each completed conversion.
pub fn enable_result_interrupt() void {
    adc.INTCTRL.modify(.{ .RESRDY = 1 });
}

/// Mask the result-ready interrupt.
pub fn disable_result_interrupt() void {
    adc.INTCTRL.modify(.{ .RESRDY = 0 });
}

/// Clear the result-ready flag (write-one-to-clear).
pub fn clear_result_flag() void {
    adc.INTFLAGS.write(.{ .RESRDY = 1, .WCMP = 0 });
}

/// Interrupt only when a result falls in (or out of) a window.
pub fn configure_window(mode: WindowMode, low: u16, high: u16, interrupt: bool) void {
    adc.WINLT = low;
    adc.WINHT = high;
    adc.CTRLE.modify(.{ .WINCM = mode });
    adc.INTCTRL.modify(.{ .WCMP = @intFromBool(interrupt) });
}

/// True when the last result satisfied the window comparison.
pub fn window_pending() bool {
    return adc.INTFLAGS.read().WCMP != 0;
}

/// Clear the window-comparator flag (write-one-to-clear).
pub fn clear_window_flag() void {
    adc.INTFLAGS.write(.{ .RESRDY = 0, .WCMP = 1 });
}

// -- Temperature -------------------------------------------------------------
//
// Procedure, equation and listing: DS40002413B section 33.3.3.8, page 500
// (listing continues onto page 501):
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=500
//
//   1. Internal 2.048V reference.          4. SAMPLEN >= 28 us x f_CLK_ADC.
//   2. TEMPSENSE as MUXPOS.                5. 12-bit right-adjusted
//   3. INITDLY >= 25 us x f_CLK_ADC.          single-ended conversion.
//   6. T(K) = (TEMPSENSE1 - RES) * TEMPSENSE0 / 4096.
//
// Both calibration words are 16-bit -- unlike tinyAVR-1/megaAVR-0's 8-bit
// gain/offset pair -- TEMPSENSE1 is the offset and TEMPSENSE0 the slope, and
// the divisor is 4096, not 256.

/// Fixed-point divisor shared by the temperature math.
pub const temperature_scaling_factor = adc_math.temperature_scaling_factor;

/// The reference the factory calibration was generated against.
pub const temperature_reference: vref.Reference = .@"2V048";

/// SIGROW calibration words for the temperature sensor.
pub const TemperatureCalibration = adc_math.TemperatureCalibration;

/// Smallest INITDLY satisfying step 3 ("INITDLY >= 25 us x f_CLK_ADC",
/// page 500).
pub fn temperature_initial_delay(clk_adc_hz: u32) InitialDelay {
    return @fromBackingInt(@intCast(adc_math.temperature_initial_delay_code(clk_adc_hz)));
}

/// Smallest SAMPLEN satisfying step 4 ("SAMPLEN >= 28 us x f_CLK_ADC").
pub fn temperature_sample_length(clk_adc_hz: u32) u8 {
    return adc_math.temperature_sample_length(clk_adc_hz);
}

/// Datasheet equation with round-to-nearest and out-of-range clamping.
pub fn temperature_kelvin(raw: u16, calibration: TemperatureCalibration) u16 {
    return adc_math.temperature_kelvin(raw, calibration);
}

/// Same reading in degrees Celsius.
pub fn temperature_celsius(raw: u16, calibration: TemperatureCalibration) i16 {
    return adc_math.temperature_celsius(raw, calibration);
}

/// Read TEMPSENSE0/1 from the signature row.
pub fn temperature_calibration() TemperatureCalibration {
    return .{
        .slope = microzig.chip.peripherals.SIGROW.TEMPSENSE0.read().TEMPSENSE0,
        .offset = microzig.chip.peripherals.SIGROW.TEMPSENSE1.read().TEMPSENSE1,
    };
}

/// ADC configuration implementing steps 1-5 of the procedure on page 500.
pub fn temperature_config(clk_adc_hz: u32, prescaler: Prescaler) Config {
    return .{
        .channel = .temperature,
        .reference = temperature_reference,
        .resolution = .@"12BIT",
        .conversion_mode = .SINGLEENDED,
        .accumulation = .NONE,
        .left_adjust = false,
        .prescaler = prescaler,
        .initial_delay = @fromBackingInt(@intCast(adc_math.temperature_initial_delay_code(clk_adc_hz))),
        .sample_length = adc_math.temperature_sample_length(clk_adc_hz),
        .configure_pin = false,
    };
}

/// Run one temperature measurement and return raw ADC codes.
/// Uses the factory procedure: 2.048 V reference, divide-by-4
/// scaling and the datasheet delay/sample times.
pub fn read_temperature_raw() u16 {
    return read_blocking();
}

/// Read the sensor and convert, in one call.
pub fn read_temperature_kelvin() u16 {
    return temperature_kelvin(read_blocking(), temperature_calibration());
}

/// Temperature in degrees Celsius from SIGROW calibration.
/// Accuracy is +/-1 LSB of the calibration, not lab grade.
pub fn read_temperature_celsius() i16 {
    return temperature_celsius(read_blocking(), temperature_calibration());
}
