//! Pure baud/SCK arithmetic for the serial HALs -- no MMIO, so these run as
//! host unit tests (`zig test src/hals/avr32dd20/serial_math.zig`).
//!
//! Sources:
//! - USART fractional baud (async): DS40002413 section 27.3.2.2.1, page 373
//!   `BAUD = 64 * f_CLK_PER / (S * f_BAUD)`, S=16 (NORMAL) or 8 (CLK2X),
//!   register range 64..65535.
//! - USART sync/MSPI: same section Table 27-1, S=2, fractional bits zero:
//!   `BAUD[15:6] = f_CLK_PER / (2 * f_BAUD)`.
//! - TWI MBAUD: DS40002413 section 29.3.2.2.1, page 424
//!   `f_SCL = f_CLK_PER / (10 + 2*BAUD + f_CLK_PER * T_RISE)`,
//!   rearranged with ceil-divide so SCL is equal or less than the request.
//! - SPI SCK: DS40002413 section 28, CTRLA.PRESC × optional CLK2X.

const std = @import("std");

pub fn usart_baud_async(clk_per_hz: u32, baud_rate: u32, samples: u16) ?u16 {
    if (baud_rate == 0) return null;
    const denominator = @as(u64, samples) * baud_rate;
    const value = (@as(u64, clk_per_hz) * 64 + denominator / 2) / denominator;
    if (value < 64 or value > 0xFFFF) return null;
    return @intCast(value);
}

pub fn usart_baud_sync(clk_per_hz: u32, baud_rate: u32) ?u16 {
    if (baud_rate == 0) return null;
    const denominator = @as(u64, 2) * baud_rate;
    const integer = (@as(u64, clk_per_hz) + denominator / 2) / denominator;
    if (integer == 0 or integer > 0x3FF) return null;
    return @intCast(integer << 6);
}

pub fn twi_baud(clk_per_hz: u32, scl_hz: u32, rise_time_ns: u32) ?u8 {
    if (scl_hz == 0) return null;
    const rise_cycles = (clk_per_hz / 1000 * rise_time_ns + 999_000) / 1_000_000;
    const total = clk_per_hz / scl_hz;
    if (total < 10 + rise_cycles) return null;
    const value = (total - 10 - rise_cycles + 1) / 2;
    if (value > 0xFF or value == 0) return null;
    return @intCast(value);
}

pub fn spi_sck_hz(clk_per_hz: u32, prescaler_div: u8, double_speed: bool) u32 {
    const d: u32 = prescaler_div;
    return if (double_speed) clk_per_hz / (d / 2) else clk_per_hz / d;
}

test "USART async baud at 24 MHz / 115200 NORMAL (S=16)" {
    // BAUD = 64 * 24e6 / (16 * 115200) = 833.333... -> 833
    try std.testing.expectEqual(@as(?u16, 833), usart_baud_async(24_000_000, 115_200, 16));
}

test "USART async baud CLK2X uses S=8" {
    // BAUD = 64 * 24e6 / (8 * 115200) = 1666.666... -> 1667
    try std.testing.expectEqual(@as(?u16, 1667), usart_baud_async(24_000_000, 115_200, 8));
}

test "USART sync baud clears fractional bits" {
    // BAUD[15:6] = 24e6 / (2 * 1e6) = 12 -> register 12 << 6 = 768
    const baud = usart_baud_sync(24_000_000, 1_000_000).?;
    try std.testing.expectEqual(@as(u16, 0), baud & 0x3F);
    try std.testing.expectEqual(@as(u16, 12), baud >> 6);
}

test "USART rejects unreachable baud" {
    try std.testing.expect(usart_baud_async(1_000_000, 2_000_000, 16) == null);
    try std.testing.expect(usart_baud_sync(1_000_000, 2_000_000) == null);
}

test "TWI MBAUD at 24 MHz / 100 kHz / 100 ns rise rounds up" {
    // rise_cycles = ceil(24e6 * 100e-9) = 3
    // total = 240, value = ceil((240 - 10 - 3) / 2) = ceil(227/2) = 114
    try std.testing.expectEqual(@as(?u8, 114), twi_baud(24_000_000, 100_000, 100));
}

test "TWI MBAUD Fast-mode-plus 1 MHz from 24 MHz stays under target" {
    const baud = twi_baud(24_000_000, 1_000_000, 100).?;
    // f_SCL = clk / (10 + 2*BAUD + rise_cycles); rise_cycles = 3
    const rise_cycles: u32 = 3;
    const denom = 10 + 2 * @as(u32, baud) + rise_cycles;
    const actual = 24_000_000 / denom;
    try std.testing.expect(actual <= 1_000_000);
}

test "SPI SCK doubles with CLK2X" {
    try std.testing.expectEqual(@as(u32, 1_500_000), spi_sck_hz(24_000_000, 16, false));
    try std.testing.expectEqual(@as(u32, 3_000_000), spi_sck_hz(24_000_000, 16, true));
}
