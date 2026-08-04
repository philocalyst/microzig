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
//! The channel numbering is sparse. On the 20-pin package the analog inputs
//! are AIN4..AIN7 on PD4..PD7, AIN22..AIN27 on PA2..PA7 and AIN29..AIN31 on
//! PC1..PC3, which is why `Channel` is a sparse enum keyed to pins.

const regs = @import("registers.zig");
const gpio = @import("gpio.zig");
const vref = @import("vref.zig");

/// ADC0.MUXPOS / ADC0.MUXNEG channel selection.
///
/// The `ainN_pXn` names carry the pin so that call sites read as the schematic
/// does. Only the internal sources listed here exist on this part.
/// DS40002413 section 33.3.3.7 "Channel Selection", page 500.
pub const Channel = enum(u8) {
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
    ain29_pc1 = 0x1D,
    ain30_pc2 = 0x1E,
    ain31_pc3 = 0x1F,

    /// Internal ground, for offset measurement.
    ground = 0x40,
    /// On-chip temperature sensor. Needs the 1.024V reference and the
    /// SIGROW calibration; see `read_temperature_kelvin`.
    temperature = 0x42,
    /// VDD divided by 10.
    vdd_div10 = 0x44,
    /// VDDIO2 (the MVIO supply for PORTC) divided by 10.
    vddio2_div10 = 0x45,
    /// DAC0 output.
    dac0 = 0x48,
    /// The AC0 DAC reference.
    dacref0 = 0x49,

    /// The GPIO pin this channel measures, or null for internal sources.
    ///
    /// A pin used as an analog input should have its digital input buffer
    /// switched off first -- see `configure_pin`.
    pub fn pin(channel: Channel) ?gpio.Pin {
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
pub const Resolution = enum(u8) {
    bits12 = 0x0,
    bits10 = 0x1,

    pub fn max_value(r: Resolution) u16 {
        return switch (r) {
            .bits12 => 4095,
            .bits10 => 1023,
        };
    }
};

/// ADC0.CTRLA.CONVMODE.
pub const ConversionMode = enum(u8) {
    /// Measure MUXPOS against ground. Result is unsigned.
    single_ended = 0x0,
    /// Measure MUXPOS minus MUXNEG. Result is signed two's complement, so
    /// read it with `read_signed`.
    differential = 0x1,
};

/// ADC0.CTRLB.SAMPNUM - burst accumulation.
///
/// DS40002413 section 33.3.3.6 "Accumulation", page 499: the accumulator adds
/// 2^n samples and the result register holds the sum, not the average, so it
/// can exceed the resolution's range. `Accumulation.count` gives the divisor.
pub const Accumulation = enum(u8) {
    none = 0x0,
    samples2 = 0x1,
    samples4 = 0x2,
    samples8 = 0x3,
    samples16 = 0x4,
    samples32 = 0x5,
    samples64 = 0x6,
    samples128 = 0x7,

    pub fn count(a: Accumulation) u8 {
        return @as(u8, 1) << @intCast(@intFromEnum(a));
    }
};

/// ADC0.CTRLC.PRESC - CLK_ADC = CLK_PER / divisor.
///
/// DS40002413 section 33.3.3.3 "Clock Generation", page 494: CLK_ADC must land
/// within the range the electrical characteristics allow (nominally
/// 125 kHz - 2 MHz for full accuracy), so pick a divisor from CLK_PER.
pub const Prescaler = enum(u8) {
    div2 = 0x0,
    div4 = 0x1,
    div8 = 0x2,
    div12 = 0x3,
    div16 = 0x4,
    div20 = 0x5,
    div24 = 0x6,
    div28 = 0x7,
    div32 = 0x8,
    div48 = 0x9,
    div64 = 0xA,
    div96 = 0xB,
    div128 = 0xC,
    div256 = 0xD,

    pub fn divisor(p: Prescaler) u16 {
        return switch (p) {
            .div2 => 2,
            .div4 => 4,
            .div8 => 8,
            .div12 => 12,
            .div16 => 16,
            .div20 => 20,
            .div24 => 24,
            .div28 => 28,
            .div32 => 32,
            .div48 => 48,
            .div64 => 64,
            .div96 => 96,
            .div128 => 128,
            .div256 => 256,
        };
    }
};

/// ADC0.CTRLD.INITDLY - settling delay after the ADC or the reference is
/// enabled, in CLK_ADC cycles.
pub const InitialDelay = enum(u8) {
    cycles0 = 0x0,
    cycles16 = 0x1,
    cycles32 = 0x2,
    cycles64 = 0x3,
    cycles128 = 0x4,
    cycles256 = 0x5,
};

/// ADC0.CTRLD.SAMPDLY - extra delay between the samples of an accumulation
/// burst, which spreads them out to decorrelate noise.
pub const SampleDelay = enum(u8) {
    cycles0 = 0x0,
    cycles1 = 0x1,
    cycles2 = 0x2,
    cycles3 = 0x3,
    cycles4 = 0x4,
    cycles5 = 0x5,
    cycles6 = 0x6,
    cycles7 = 0x7,
    cycles8 = 0x8,
    cycles9 = 0x9,
    cycles10 = 0xA,
    cycles11 = 0xB,
    cycles12 = 0xC,
    cycles13 = 0xD,
    cycles14 = 0xE,
    cycles15 = 0xF,
};

/// ADC0.CTRLE.WINCM - window comparator mode.
///
/// DS40002413 section 33.3.3.9 "Window Comparator", page 501.
pub const WindowMode = enum(u8) {
    none = 0x0,
    below_low = 0x1,
    above_high = 0x2,
    inside = 0x3,
    outside = 0x4,
};

pub const Config = struct {
    channel: Channel = .ain22_pa2,
    /// Only used in differential mode.
    negative_channel: Channel = .ground,
    reference: vref.Reference = .vdd,
    resolution: Resolution = .bits12,
    conversion_mode: ConversionMode = .single_ended,
    accumulation: Accumulation = .none,
    prescaler: Prescaler = .div16,
    initial_delay: InitialDelay = .cycles0,
    sample_delay: SampleDelay = .cycles0,
    /// SAMPCTRL.SAMPLEN - extra CLK_ADC cycles of sample time, for sources
    /// with a high output impedance.
    sample_length: u8 = 0,
    /// CTRLA.FREERUN - start the next conversion as soon as one finishes.
    free_running: bool = false,
    /// CTRLA.LEFTADJ - left-align the result in the 16-bit register.
    left_adjust: bool = false,
    /// CTRLA.RUNSTBY - keep converting in standby sleep.
    run_standby: bool = false,
    /// EVCTRL.STARTEI - start a conversion from an event channel.
    start_on_event: bool = false,
    /// Also configure the input pin: disable its digital input buffer, which
    /// the datasheet requires for an analog input.
    configure_pin: bool = true,
};

/// Configure and enable the ADC.
///
/// DS40002413 section 33.3.2 "Initialization", page 492: set up the reference
/// and the mux before setting CTRLA.ENABLE, which is what this ordering does.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=492
pub fn configure(config: Config) void {
    regs.write(regs.adc0.ctrla, 0);

    vref.set_adc0_reference(config.reference);

    if (config.configure_pin) {
        if (config.channel.pin()) |p| disable_digital_input(p);
        if (config.conversion_mode == .differential) {
            if (config.negative_channel.pin()) |p| disable_digital_input(p);
        }
    }

    regs.write(regs.adc0.muxpos, @intFromEnum(config.channel));
    regs.write(regs.adc0.muxneg, @intFromEnum(config.negative_channel));
    regs.write(regs.adc0.ctrlb, @intFromEnum(config.accumulation));
    regs.write(regs.adc0.ctrlc, @intFromEnum(config.prescaler));
    regs.write(
        regs.adc0.ctrld,
        @intFromEnum(config.sample_delay) | (@as(u8, @intFromEnum(config.initial_delay)) << 5),
    );
    regs.write(regs.adc0.sampctrl, config.sample_length);
    regs.write(regs.adc0.evctrl, if (config.start_on_event) regs.bit(regs.adc0.startei) else 0);

    var ctrla: u8 = regs.bit(regs.adc0.enable) |
        (@as(u8, @intFromEnum(config.resolution)) << 2) |
        (@as(u8, @intFromEnum(config.conversion_mode)) << 5);
    if (config.free_running) ctrla |= regs.bit(regs.adc0.freerun);
    if (config.left_adjust) ctrla |= regs.bit(regs.adc0.leftadj);
    if (config.run_standby) ctrla |= regs.bit(regs.adc0.runstby);
    regs.write(regs.adc0.ctrla, ctrla);
}

/// Turn off a pin's digital input buffer, as required for an analog input.
///
/// DS40002413 section 33.3.4 "I/O Lines and Connections", page 501: leaving the
/// digital input enabled on an analog pin both wastes current and injects
/// switching noise into the measurement.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=501
pub fn disable_digital_input(p: gpio.Pin) void {
    gpio.set_direction(p, .input);
    gpio.configure(p, .{ .sense = .input_disable });
}

pub fn disable() void {
    regs.clear_bits(regs.adc0.ctrla, regs.bit(regs.adc0.enable));
}

/// Point the positive mux at a different channel between conversions.
pub fn select_channel(channel: Channel) void {
    regs.write(regs.adc0.muxpos, @intFromEnum(channel));
}

pub fn select_negative_channel(channel: Channel) void {
    regs.write(regs.adc0.muxneg, @intFromEnum(channel));
}

/// Start a conversion (COMMAND.STCONV).
pub fn start() void {
    regs.write(regs.adc0.command, regs.bit(regs.adc0.stconv));
}

/// Abort an in-flight conversion, including a free-running sequence.
pub fn stop() void {
    regs.write(regs.adc0.command, regs.bit(regs.adc0.spconv));
}

pub fn result_ready() bool {
    return (regs.read(regs.adc0.intflags) & regs.bit(regs.adc0.resrdy)) != 0;
}

/// Raw contents of ADC0.RES.
///
/// DS40002413 section 33.3.3.5 "Conversion Result (Output Formats)", page 497:
/// reading RES clears RESRDY, so a handler does not need to clear the flag
/// separately.
pub fn read_raw() u16 {
    return regs.mem16(regs.adc0.res).*;
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
pub fn read_channel_blocking(channel: Channel) u16 {
    select_channel(channel);
    return read_blocking();
}

/// Average of an accumulated burst.
///
/// The result register holds the *sum*, so divide by the sample count to get
/// back to the configured resolution.
pub fn average(raw: u16, accumulation: Accumulation) u16 {
    return raw / accumulation.count();
}

/// Convert a single-ended raw reading to millivolts.
pub fn to_millivolts(raw: u16, reference: vref.Reference, resolution: Resolution) u32 {
    const reference_mv = reference.millivolts() orelse return 0;
    return (@as(u32, raw) * reference_mv) / (@as(u32, resolution.max_value()) + 1);
}

// -- Interrupts and window comparator ---------------------------------------

pub fn enable_result_interrupt() void {
    regs.set_bits(regs.adc0.intctrl, regs.bit(regs.adc0.resrdy));
}

pub fn disable_result_interrupt() void {
    regs.clear_bits(regs.adc0.intctrl, regs.bit(regs.adc0.resrdy));
}

pub fn clear_result_flag() void {
    regs.write(regs.adc0.intflags, regs.bit(regs.adc0.resrdy));
}

/// Have the ADC raise an interrupt only when a result falls in (or out of) a
/// window, so routine in-range samples cost no CPU time.
pub fn configure_window(mode: WindowMode, low: u16, high: u16, interrupt: bool) void {
    regs.mem16(regs.adc0.winlt).* = low;
    regs.mem16(regs.adc0.winht).* = high;
    regs.write(regs.adc0.ctrle, @intFromEnum(mode));
    if (interrupt) {
        regs.set_bits(regs.adc0.intctrl, regs.bit(regs.adc0.wcmp));
    } else {
        regs.clear_bits(regs.adc0.intctrl, regs.bit(regs.adc0.wcmp));
    }
}

pub fn window_pending() bool {
    return (regs.read(regs.adc0.intflags) & regs.bit(regs.adc0.wcmp)) != 0;
}

pub fn clear_window_flag() void {
    regs.write(regs.adc0.intflags, regs.bit(regs.adc0.wcmp));
}

// -- Temperature -------------------------------------------------------------
//
// DS40002413 section 33.3.3.8 "Temperature Measurement", page 500, gives the
// procedure and the equation; the reference code listing is on page 501.
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=500
//
// The datasheet's own listing is:
//
//     uint16_t sigrow_offset = SIGROW.TEMPSENSE1;
//     uint16_t sigrow_slope  = SIGROW.TEMPSENSE0;
//     uint16_t adc_reading   = ADCn.RES;
//     uint32_t temp = sigrow_offset - adc_reading;
//     temp *= sigrow_slope;
//     temp += SCALING_FACTOR / 2;
//     temp /= SCALING_FACTOR;              // SCALING_FACTOR is 4096
//     uint16_t temperature_in_K = temp;
//     int16_t  temperature_in_C = temp - 273;
//
// Note how little of this survives from tinyAVR-1/megaAVR-0: both calibration
// words are 16-bit, TEMPSENSE1 is the *offset* and TEMPSENSE0 the *slope*, the
// subtraction runs offset-minus-reading, and the divisor is 4096 rather than
// 256. The reference is the internal 2.048V, not 1.024V.

/// Divisor the signature-row slope is scaled by, so that it can be stored as a
/// whole number.
pub const temperature_scaling_factor: u32 = 4096;

/// The reference the factory calibration values are generated against.
pub const temperature_reference: vref.Reference = .internal_2v048;

/// Factory calibration for the on-chip temperature sensor.
pub const TemperatureCalibration = struct {
    /// SIGROW.TEMPSENSE0 - slope of the sensor characteristic.
    slope: u16,
    /// SIGROW.TEMPSENSE1 - offset of the sensor characteristic.
    offset: u16,

    /// Rescale the calibration for a reference other than 2.048V.
    ///
    /// DS40002413 section 33.3.3.8, page 501:
    /// `Slope = TEMPSENSE0 * V_ADCREF / 2.048V` and
    /// `Offset = TEMPSENSE1 * 2.048V / V_ADCREF`.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=501
    ///
    /// Returns null for VDD and the external pin, whose voltage the device
    /// cannot know.
    pub fn for_reference(c: TemperatureCalibration, reference: vref.Reference) ?TemperatureCalibration {
        const reference_mv = reference.millivolts() orelse return null;
        return .{
            .slope = @intCast((@as(u32, c.slope) * reference_mv) / 2048),
            .offset = @intCast((@as(u32, c.offset) * 2048) / reference_mv),
        };
    }
};

pub fn temperature_calibration() TemperatureCalibration {
    return .{
        .slope = regs.mem16(regs.sigrow.tempsense0).*,
        .offset = regs.mem16(regs.sigrow.tempsense1).*,
    };
}

/// Smallest INITDLY that satisfies the datasheet's "at least 25 us" settling
/// requirement at the given ADC clock.
pub fn temperature_initial_delay(clk_adc_hz: u32) InitialDelay {
    const cycles = (clk_adc_hz / 1000 * 25) / 1000; // 25 us, in CLK_ADC cycles
    return if (cycles <= 16)
        .cycles16
    else if (cycles <= 32)
        .cycles32
    else if (cycles <= 64)
        .cycles64
    else if (cycles <= 128)
        .cycles128
    else
        .cycles256;
}

/// SAMPCTRL.SAMPLEN satisfying the datasheet's "at least 28 us" sample time.
/// Saturates at the register's 255-cycle maximum.
pub fn temperature_sample_length(clk_adc_hz: u32) u8 {
    const cycles = (clk_adc_hz / 1000 * 28) / 1000;
    return @intCast(@min(cycles, 255));
}

/// ADC configuration for a temperature reading, per the six-step procedure in
/// DS40002413 section 33.3.3.8, page 500: internal 2.048V reference, the
/// temperature sensor as MUXPOS, a settling delay and a long sample time, and
/// a 12-bit right-adjusted single-ended conversion.
///
/// `clk_adc_hz` is CLK_PER divided by the ADC prescaler; `Prescaler.divisor`
/// gives the divisor.
pub fn temperature_config(clk_adc_hz: u32, prescaler: Prescaler) Config {
    return .{
        .channel = .temperature,
        .reference = temperature_reference,
        .resolution = .bits12,
        .conversion_mode = .single_ended,
        .accumulation = .none,
        .left_adjust = false,
        .prescaler = prescaler,
        .initial_delay = temperature_initial_delay(clk_adc_hz),
        .sample_length = temperature_sample_length(clk_adc_hz),
        .configure_pin = false,
    };
}

/// Apply the datasheet equation to a 12-bit reading.
///
/// `T(K) = (Offset - ADC result) * Slope / 4096`, rounded to nearest.
///
/// The datasheet's listing does this in a `uint32_t`, which silently wraps to
/// roughly 65000 K if the reading ever exceeds the offset. Microchip's own
/// reference example for the AVR128DA48 Curiosity Nano uses a signed `int32_t`
/// for the same arithmetic, which is what this follows -- with the result
/// clamped at zero, so an out-of-range reading is visibly wrong rather than
/// plausible.
pub fn temperature_kelvin(raw: u16, calibration: TemperatureCalibration) u16 {
    const difference = @as(i32, calibration.offset) - @as(i32, raw);
    if (difference <= 0) return 0;

    var temp: u32 = @intCast(difference);
    temp *= calibration.slope; // overflows 16 bits, hence u32
    temp += temperature_scaling_factor / 2; // round instead of truncate
    temp /= temperature_scaling_factor;
    return @intCast(@min(temp, 0xFFFF));
}

/// Same reading in degrees Celsius.
pub fn temperature_celsius(raw: u16, calibration: TemperatureCalibration) i16 {
    return @as(i16, @intCast(temperature_kelvin(raw, calibration))) - 273;
}

/// Raw 12-bit reading from the temperature sensor. Configure with
/// `temperature_config` first.
pub fn read_temperature_raw() u16 {
    return read_blocking();
}

/// Read the sensor and convert, in one call.
///
/// Assumes the ADC is already configured with `temperature_config`. If
/// accumulation is enabled the datasheet requires scaling the result back to
/// 12 bits before converting, which `temperature_config` avoids by turning
/// accumulation off.
pub fn read_temperature_kelvin() u16 {
    return temperature_kelvin(read_blocking(), temperature_calibration());
}

pub fn read_temperature_celsius() i16 {
    return temperature_celsius(read_blocking(), temperature_calibration());
}
