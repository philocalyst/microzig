//! SPI0 - Serial Peripheral Interface.
//!
//! DS40002413 section 28 "SPI - Serial Peripheral Interface", page 405.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=405
//!
//! Route the pins with `portmux.set_spi0` before calling `configure`; the
//! default position is MOSI PA4, MISO PA5, SCK PA6, SS PA7.

const regs = @import("registers.zig");
const gpio = @import("gpio.zig");

/// CTRLA.PRESC, bits 2:1. Combined with CLK2X this gives eight SCK rates.
pub const Prescaler = enum(u8) {
    div4 = 0x0,
    div16 = 0x1,
    div64 = 0x2,
    div128 = 0x3,

    pub fn divisor(p: Prescaler) u8 {
        return switch (p) {
            .div4 => 4,
            .div16 => 16,
            .div64 => 64,
            .div128 => 128,
        };
    }
};

/// CTRLB.MODE - the usual CPOL/CPHA quadrant.
pub const Mode = enum(u8) {
    /// CPOL 0, CPHA 0: sample on rising, idle low.
    mode0 = 0x0,
    /// CPOL 0, CPHA 1: sample on falling, idle low.
    mode1 = 0x1,
    /// CPOL 1, CPHA 0: sample on falling, idle high.
    mode2 = 0x2,
    /// CPOL 1, CPHA 1: sample on rising, idle high.
    mode3 = 0x3,
};

pub const BitOrder = enum { msb_first, lsb_first };

pub const Config = struct {
    /// Host (controller) or client (peripheral).
    host: bool = true,
    mode: Mode = .mode0,
    bit_order: BitOrder = .msb_first,
    prescaler: Prescaler = .div16,
    /// CTRLA.CLK2X - halve the prescaler divisor.
    double_speed: bool = false,
    /// CTRLB.SSD - in host mode, ignore the SS pin so it can be an ordinary
    /// GPIO. Without this a low on SS drops the peripheral out of host mode.
    /// DS40002413 section 28.3.2.1.3 "SS Pin Functionality in Host Mode",
    /// page 407.
    disable_ss: bool = true,
    /// CTRLB.BUFEN - buffered mode, which adds a one-deep TX buffer and a
    /// two-deep RX FIFO. Changes the meaning of INTFLAGS, so the helpers below
    /// assume normal mode.
    buffered: bool = false,
};

/// Resulting SCK frequency for a given peripheral clock.
pub fn sck_hz(clk_per_hz: u32, prescaler: Prescaler, double_speed: bool) u32 {
    const divisor: u32 = prescaler.divisor();
    return if (double_speed) clk_per_hz / (divisor / 2) else clk_per_hz / divisor;
}

/// Configure and enable SPI0.
///
/// DS40002413 section 28.3.1 "Initialization", page 406: in host mode the
/// direction of MOSI, SCK and SS must be set by software -- the peripheral
/// overrides the pin *values* but not the data direction.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=406
pub fn configure(config: Config) void {
    regs.write(regs.spi0.ctrla, 0);

    var ctrlb: u8 = @intFromEnum(config.mode);
    if (config.disable_ss) ctrlb |= regs.bit(regs.spi0.ssd);
    if (config.buffered) ctrlb |= regs.bit(regs.spi0.bufen);
    regs.write(regs.spi0.ctrlb, ctrlb);

    var ctrla: u8 = regs.bit(regs.spi0.enable) | (@as(u8, @intFromEnum(config.prescaler)) << 1);
    if (config.host) ctrla |= regs.bit(regs.spi0.master);
    if (config.bit_order == .lsb_first) ctrla |= regs.bit(regs.spi0.dord);
    if (config.double_speed) ctrla |= regs.bit(regs.spi0.clk2x);
    regs.write(regs.spi0.ctrla, ctrla);
}

/// Set the data direction of the host-side pins for a given pin position.
///
/// The peripheral does not do this for you, so call it after `portmux.set_spi0`
/// and before the first transfer.
pub fn configure_host_pins(mosi: gpio.Pin, sck: gpio.Pin, miso: gpio.Pin) void {
    gpio.set_direction(mosi, .output);
    gpio.set_direction(sck, .output);
    gpio.set_direction(miso, .input);
}

pub fn disable() void {
    regs.clear_bits(regs.spi0.ctrla, regs.bit(regs.spi0.enable));
}

/// Exchange one byte, blocking until the transfer completes.
pub fn transfer(byte: u8) u8 {
    regs.write(regs.spi0.data, byte);
    while ((regs.read(regs.spi0.intflags) & regs.bit(regs.spi0.spi_if)) == 0) {}
    return regs.read(regs.spi0.data);
}

pub fn write_byte(byte: u8) void {
    _ = transfer(byte);
}

/// Clock out a dummy byte to read one in.
pub fn read_byte() u8 {
    return transfer(0xFF);
}

pub fn write_all(bytes: []const u8) void {
    for (bytes) |byte| write_byte(byte);
}

pub fn read_all(buffer: []u8) void {
    for (buffer) |*byte| byte.* = read_byte();
}

/// Full-duplex transfer. `tx` and `rx` may alias.
pub fn transfer_all(tx: []const u8, rx: []u8) void {
    const len = @min(tx.len, rx.len);
    for (0..len) |i| rx[i] = transfer(tx[i]);
}

/// True if a write to DATA happened while a transfer was still in flight; the
/// write was discarded.
pub fn write_collision() bool {
    return (regs.read(regs.spi0.intflags) & regs.bit(regs.spi0.wrcol)) != 0;
}

pub fn enable_interrupt() void {
    regs.set_bits(regs.spi0.intctrl, regs.bit(0));
}

pub fn disable_interrupts() void {
    regs.write(regs.spi0.intctrl, 0);
}
