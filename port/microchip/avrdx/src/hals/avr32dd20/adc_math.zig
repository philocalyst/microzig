//! Pure arithmetic behind the ADC driver -- no hardware access, so these run
//! as host unit tests (`zig test src/hals/avr32dd20/adc_math.zig`).
//!
//! Sources for every rule:
//! - Result formats and truncation above 16 samples:
//!   DS40002413B section 33.3.3.6 "Accumulation", page 499, Tables 33-1 and
//!   33-2 ("Truncated Accumulation [15:0]" rows).
//!   https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=499
//! - Temperature procedure, equation and reference listing:
//!   DS40002413B section 33.3.3.8 "Temperature Measurement", page 500.
//!   https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=500

const std = @import("std");

/// Number of samples summed by each CTRLB.SAMPNUM encoding.
pub fn accumulation_count(sampnum: u3) u16 {
    return @as(u16, 1) << sampnum;
}

/// How many LSBs the hardware truncated from RES for this SAMPNUM, per
/// Table 33-1/33-2 (only 32/64/128 lose bits).
pub fn accumulation_truncated_bits(sampnum: u3) u5 {
    return switch (sampnum) {
        5 => 1, // ACC32
        6 => 2, // ACC64
        7 => 3, // ACC128
        else => 0,
    };
}

/// Recover the approximate pre-truncation sum from RES.
pub fn accumulation_rescale(sampnum: u3, raw: u16) u32 {
    return @as(u32, raw) << accumulation_truncated_bits(sampnum);
}

/// Average of an accumulated burst, back in the configured resolution's range.
///
/// For 1..16 samples RES is the exact sum, so this divides it. For 32/64/128
/// the hardware already discarded `truncated_bits` LSBs of the sum; the best
/// recoverable average is therefore raw >> (log2(count) - truncated_bits),
/// which equals raw >> 4 for all three truncated cases.
pub fn accumulation_average(sampnum: u3, raw: u16) u16 {
    const n = accumulation_count(sampnum);
    if (n == 1) return raw;
    const s = accumulation_truncated_bits(sampnum);
    if (s == 0) return @intCast(raw / n);
    const shift: u4 = @intCast(@as(u8, @ctz(n)) - s);
    return raw >> shift;
}

/// Smallest INITDLY encoding satisfying a ">= cycles" requirement. The
/// register steps are DLY0=0, DLY16=16, DLY32=32, DLY64=64, DLY128=128,
/// DLY256=256 CLK_ADC cycles.
pub fn initial_delay_for_cycles(cycles_needed: u32) u3 {
    return switch (cycles_needed) {
        0 => 0,
        1...16 => 1,
        17...32 => 2,
        33...64 => 3,
        65...128 => 4,
        else => 5,
    };
}

/// INITDLY value for the temperature procedure's "INITDLY >= 25 us x
/// f_CLK_ADC" step. Rounds *up*: flooring could leave the sensor unsettled.
pub fn temperature_initial_delay_code(clk_adc_hz: u32) u3 {
    return initial_delay_for_cycles((clk_adc_hz + 39_999) / 40_000);
}

/// SAMPLEN register value for the procedure's "SAMPLEN >= 28 us x f_CLK_ADC"
/// step. Rounds up, saturating at the register's 255-cycle maximum.
pub fn temperature_sample_length(clk_adc_hz: u32) u8 {
    const cycles = (clk_adc_hz * 7 + 249_999) / 250_000;
    return @intCast(@min(cycles, 255));
}

/// Fixed-point divisor applied after shifting the raw temperature left by 4:
/// keeps the intermediate in u32 without losing the calibration's LSB.
pub const temperature_scaling_factor: u32 = 4096;

/// Factory calibration words from SIGROW.TEMPSENSE0 (slope) and TEMPSENSE1
/// (offset); both are generated against an internal 2.048V reference.
pub const TemperatureCalibration = struct {
    slope: u16,
    offset: u16,

    /// Rescale for another reference:
    ///   Slope  = TEMPSENSE0 x V_REF / 2.048V
    ///   Offset = TEMPSENSE1 x 2.048V / V_REF      (DS40002413B p. 500)
    pub fn for_reference(
        c: TemperatureCalibration,
        reference_mv: ?u32,
    ) ?TemperatureCalibration {
        const mv = reference_mv orelse return null;
        return .{
            .slope = @intCast((@as(u32, c.slope) * mv) / 2048),
            .offset = @intCast((@as(u32, c.offset) * 2048) / mv),
        };
    }
};

/// T(K) = (offset - reading) x slope / 4096, rounded to nearest, clamped at
/// zero so an out-of-range reading reads as visibly wrong instead of wrapping
/// like the datasheet's uint32_t listing would.
pub fn temperature_kelvin(raw: u16, calibration: TemperatureCalibration) u16 {
    const difference = @as(i32, calibration.offset) - @as(i32, raw);
    if (difference <= 0) return 0;

    var temp: u32 = @intCast(difference);
    temp *= calibration.slope;
    temp += temperature_scaling_factor / 2;
    temp /= temperature_scaling_factor;
    return @intCast(@min(temp, 0xFFFF));
}

/// Convert a raw temperature reading to degrees Celsius.
///
/// `temperature_kelvin` does the calibration math; this only applies the
/// 273.15 offset, truncated to 273 because the sensor's accuracy is far
/// coarser than the fraction.
pub fn temperature_celsius(raw: u16, calibration: TemperatureCalibration) i16 {
    return @as(i16, @intCast(temperature_kelvin(raw, calibration))) - 273;
}

// -- Tests -------------------------------------------------------------------

const testing = std.testing;

test "accumulation counts follow 2^n" {
    try testing.expectEqual(@as(u16, 1), accumulation_count(0));
    try testing.expectEqual(@as(u16, 128), accumulation_count(7));
}

test "truncation only happens above 16 samples (Table 33-1)" {
    var i: u3 = 0;
    while (i < 5) : (i += 1) {
        try testing.expectEqual(@as(u5, 0), accumulation_truncated_bits(i));
    }
    try testing.expectEqual(@as(u5, 1), accumulation_truncated_bits(5));
    try testing.expectEqual(@as(u5, 2), accumulation_truncated_bits(6));
    try testing.expectEqual(@as(u5, 3), accumulation_truncated_bits(7));
}

test "average of non-truncated bursts divides exactly" {
    try testing.expectEqual(@as(u16, 1234), accumulation_average(0, 1234));
    try testing.expectEqual(@as(u16, 4000), accumulation_average(2, 16000));
    try testing.expectEqual(@as(u16, 2000), accumulation_average(4, 32000));
}

test "average of truncated bursts shifts instead of dividing" {
    // ACC32: RES holds sum>>1, average = sum/32 = floor(RES/16).
    try testing.expectEqual(@as(u16, 4095), accumulation_average(5, 0xFFFF));
    try testing.expectEqual(@as(u16, 2048), accumulation_average(5, 0x8000));
    // ACC64 and ACC128 collapse to the same shift.
    try testing.expectEqual(@as(u16, 4095), accumulation_average(6, 0xFFFF));
    try testing.expectEqual(@as(u16, 4095), accumulation_average(7, 0xFFFF));

    // Round trip: rescale(RES)/count == average(RES).
    var raw: u32 = 0;
    while (raw < 65536) : (raw += 7777) {
        const r: u16 = @intCast(raw);
        const avg = @as(u64, accumulation_rescale(6, r)) / 64;
        try testing.expectEqual(@as(u64, accumulation_average(6, r)), avg);
    }
}

test "initial delay picks the smallest sufficient step" {
    try testing.expectEqual(@as(u3, 0), initial_delay_for_cycles(0));
    // DLY0 means zero cycles, so any nonzero requirement needs DLY16.
    try testing.expectEqual(@as(u3, 1), initial_delay_for_cycles(16));
    try testing.expectEqual(@as(u3, 2), initial_delay_for_cycles(17));
    try testing.expectEqual(@as(u3, 3), initial_delay_for_cycles(64));
    try testing.expectEqual(@as(u3, 4), initial_delay_for_cycles(65));
    try testing.expectEqual(@as(u3, 5), initial_delay_for_cycles(257));
}

test "temperature delays round up (minimum requirements, p.500)" {
    // Exactly on a boundary needs that boundary itself.
    try testing.expectEqual(@as(u3, 2), temperature_initial_delay_code(32 * 40_000));
    // Just over needs the next step up.
    try testing.expectEqual(@as(u3, 3), temperature_initial_delay_code(32 * 40_000 + 1));
    // 24 MHz / 16 prescaler = 1.5 MHz CLK_ADC: ceil(37.5) = 38 -> DLY64.
    try testing.expectEqual(@as(u3, 3), temperature_initial_delay_code(1_500_000));

    // 28us at 1 MHz = 28 cycles exactly.
    try testing.expectEqual(@as(u8, 28), temperature_sample_length(1_000_000));
    // Fractional cycle counts round up: 1035715 x 28us = 29.00002 us-cycles.
    try testing.expectEqual(@as(u8, 30), temperature_sample_length(1_035_715));
    // Saturate at the register maximum.
    try testing.expectEqual(@as(u8, 255), temperature_sample_length(100_000_000));
}

test "temperature equation matches the datasheet listing" {
    const cal = TemperatureCalibration{ .slope = 16384, .offset = 2000 };
    try testing.expectEqual(@as(u16, 4000), temperature_kelvin(1000, cal));
    // Reading equal to the offset clamps at absolute zero rather than
    // wrapping like the C listing does.
    try testing.expectEqual(@as(u16, 0), temperature_kelvin(2000, cal));
    try testing.expectEqual(@as(i16, -273), temperature_celsius(2000, cal));
}

test "calibration rescale follows the datasheet formulas" {
    const cal = TemperatureCalibration{ .slope = 4096, .offset = 2000 };
    // Same reference: unchanged.
    const same = cal.for_reference(2048).?;
    try testing.expectEqual(cal.slope, same.slope);
    try testing.expectEqual(cal.offset, same.offset);
    // 1.024V: slope halves, offset doubles.
    const low = cal.for_reference(1024).?;
    try testing.expectEqual(@as(u16, 2048), low.slope);
    try testing.expectEqual(@as(u16, 4000), low.offset);
    // Unknown reference voltage: cannot rescale.
    try testing.expectEqual(@as(?TemperatureCalibration, null), cal.for_reference(null));
}
