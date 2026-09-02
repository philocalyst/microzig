//! SPI0 - Serial Peripheral Interface.
//!
//! DS40002413 section 28 "SPI - Serial Peripheral Interface", page 405.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=405
//!
//! Route the pins with `portmux.set_spi0` before calling `configure`; the
//! default position is MOSI PA4, MISO PA5, SCK PA6, SS PA7.
//!
//! Host (`configure`) and client (`configure_client`) paths are wrapped, plus
//! buffered-mode byte helpers. `transfer` / `write_collision` assume normal
//! mode (CTRLB.BUFEN=0); use the `*_buffered` helpers when BUFEN=1. Mode-
//! discriminated config unions that make the wrong helper unrepresentable are
//! still incomplete.

const microzig = @import("microzig");

const spi = microzig.chip.peripherals.SPI0;
const gen = microzig.chip.types.peripherals.SPI;

const serial_math = @import("serial_math.zig");

const CtrlABits = @TypeOf(spi.CTRLA.read());
const CtrlBBits = @TypeOf(spi.CTRLB.read());
const IntflagsBits = @TypeOf(spi.INTFLAGS.read());

/// CTRLA.PRESC. Combined with CLK2X this gives eight SCK rates. Encodings
/// re-exported from the generated layer.
pub const Prescaler = gen.SPI_PRESC;

/// Numeric CLK_PER division factor of a prescaler setting.
pub fn prescaler_divisor(p: Prescaler) u8 {
    return switch (p) {
        .DIV4 => 4,
        .DIV16 => 16,
        .DIV64 => 64,
        .DIV128 => 128,
    };
}

/// CTRLB.MODE - the usual CPOL/CPHA quadrant. Encodings re-exported from the
/// generated layer.
pub const Mode = gen.SPI_MODE;

/// Which end of the byte shifts out first.
pub const BitOrder = enum { msb_first, lsb_first };

/// SPI configuration shared by host and client modes.
pub const Config = struct {
    /// Host (controller) or client (peripheral).
    host: bool = true,
    mode: Mode = .@"0",
    bit_order: BitOrder = .msb_first,
    prescaler: Prescaler = .DIV16,
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
    return serial_math.spi_sck_hz(clk_per_hz, prescaler_divisor(prescaler), double_speed);
}

/// Configure and enable SPI0 as host.
///
/// DS40002413 section 28.3.1 "Initialization", page 406: in host mode the
/// direction of MOSI, SCK and SS must be set by software -- the peripheral
/// overrides the pin *values* but not the data direction.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=406
pub fn configure(config: Config) void {
    spi.CTRLA.write(.{
        .ENABLE = 0,
        .PRESC = config.prescaler,
        .CLK2X = @intFromBool(config.double_speed),
        .MASTER = @intFromBool(config.host),
        .DORD = @intFromBool(config.bit_order == .lsb_first),
    });

    spi.CTRLB.write(.{
        .MODE = config.mode,
        .SSD = @intFromBool(config.disable_ss),
        .BUFWR = 0,
        .BUFEN = @intFromBool(config.buffered),
    });

    spi.CTRLA.modify(.{ .ENABLE = 1 });
}

/// Set the data direction of the host-side pins for a given pin position.
///
/// The peripheral does not do this for you, so call it after
/// `portmux.set_spi0` and before the first transfer.
pub fn configure_host_pins(mosi: anytype, sck: anytype, miso: anytype) void {
    mosi.set_direction_rt(mosi, .output);
    sck.set_direction_rt(sck, .output);
    _ = miso;
}

/// Disable the peripheral (CTRLA.ENABLE = 0).
pub fn disable() void {
    spi.CTRLA.modify(.{ .ENABLE = 0 });
}

/// Exchange one byte, blocking until the transfer completes.
pub fn transfer(byte: u8) u8 {
    spi.DATA = byte;
    // In normal mode the transfer-complete flag is INTFLAGS bit 7; the
    // generated type carries its buffered-mode name (RXCIF) for the same bit
    // position, per DS40002413 sections 28.5.4 "Interrupt Flags - Normal
    // Mode" (page 418) and 28.5.5 "Interrupt Flags - Buffer Mode"
    // (page 419) describing the unified flag layout.
    while ((spi.INTFLAGS.raw & 0x80) == 0) {}
    return spi.DATA;
}

/// Transmit one byte and wait for it to leave the shift register.
pub fn write_byte(byte: u8) void {
    _ = transfer(byte);
}

/// Clock out a dummy byte to read one in.
pub fn read_byte() u8 {
    return transfer(0xFF);
}

/// Send a buffer; received bytes are discarded.
pub fn write_all(bytes: []const u8) void {
    for (bytes) |byte| write_byte(byte);
}

/// Receive a buffer by clocking out 0xFF dummy bytes.
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
/// Normal-mode write-collision flag: INTFLAGS bit 6 (buffered-mode name
/// TXCIF for the same bit; see the note at `transfer`).
pub fn write_collision() bool {
    return (spi.INTFLAGS.raw & 0x40) != 0;
}

/// Raise the SPI interrupt when a byte completes (INTCTRL.IE).
pub fn enable_interrupt() void {
    spi.INTCTRL.modify(.{ .IE = 1 });
}

/// Mask every SPI interrupt source.
pub fn disable_interrupts() void {
    spi.INTCTRL.write(.{ .IE = 0, .SSIE = 0, .DREIE = 0, .TXCIE = 0, .RXCIE = 0 });
}

// -- Client mode and buffered mode -------------------------------------------
//
// DS40002413 section 28.3.2.2 "Buffered Mode", page 408, and section
// 28.3.2.1.2 "SS Pin Functionality in Client Mode", page 407: with SS low the
// peripheral drives MISO; SS high tri-states it, so several clients can share
// one bus without extra glue.
//
// Buffered mode (CTRLB.BUFEN) adds a one-deep TX buffer and two-deep RX FIFO.
// In this mode DREIF/RXCIF/TXCIF carry their documented meanings from the
// generated INTFLAGS type directly -- no bit-aliasing games like normal mode.

/// Client-mode configuration. Buffered mode is on by default: the
/// extra RX FIFO buys the handler time between back-to-back bytes.
pub const ClientConfig = struct {
    mode: Mode = .@"0",
    bit_order: BitOrder = .msb_first,
    /// CTRLB.BUFEN. Recommended for clients: the RX FIFO buys the interrupt
    /// handler time between back-to-back bytes.
    buffered: bool = true,
    /// CTRLB.BUFWR. When set, the first byte written to DATA waits for a
    /// received byte before transmitting; when clear (the reset default) a
    /// dummy byte goes out first.
    wait_for_receive: bool = false,
    enable_interrupt: bool = false,
};

/// Configure and enable SPI0 as a client.
///
/// MISO must already be an output for the peripheral to drive it; SS is an
/// input regardless of DIR (section 28.3.2.1.2).
pub fn configure_client(config: ClientConfig) void {
    spi.CTRLA.write(.{
        .ENABLE = 0,
        .PRESC = .DIV4,
        .CLK2X = 0,
        .MASTER = 0,
        .DORD = @intFromBool(config.bit_order == .lsb_first),
    });

    spi.CTRLB.write(.{
        .MODE = config.mode,
        .SSD = 0,
        .BUFWR = @intFromBool(config.wait_for_receive),
        .BUFEN = @intFromBool(config.buffered),
    });

    spi.INTCTRL.write(.{
        .IE = @intFromBool(config.enable_interrupt),
        .SSIE = 0,
        .DREIE = 0,
        .TXCIE = 0,
        .RXCIE = 0,
    });

    spi.CTRLA.modify(.{ .ENABLE = 1 });
}

/// True when the peripheral was in host mode and SS was pulled low
/// externally, forcing the transition into client mode (INTFLAGS.SSIF, bit 4;
/// buffered mode only). Cleared by writing one.
///
/// DS40002413 section 28.5.5 "Interrupt Flags - Buffer Mode", page 419.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=419
pub fn select_triggered() bool {
    return spi.INTFLAGS.read().SSIF != 0;
}

/// Acknowledge SSIF after another master forced us into client mode.
pub fn clear_select_trigger() void {
    var flags: IntflagsBits = spi.INTFLAGS.read();
    flags.SSIF = 1;
    spi.INTFLAGS.write(flags);
}

/// Buffered-mode transmit: DATA accepts bytes whenever DREIF is set (one in
/// flight plus one queued). Blocks until there is room.
pub fn write_byte_buffered(byte: u8) void {
    // In buffered mode DREIF is INTFLAGS bit 5 under its generated name.
    while ((spi.INTFLAGS.raw & 0x20) == 0) {}
    spi.DATA = byte;
}

/// Buffered-mode receive: pops one byte from the RX FIFO once RXCIF (bit 7)
/// shows data available.
pub fn read_byte_buffered() u8 {
    while ((spi.INTFLAGS.raw & 0x80) == 0) {}
    return spi.DATA;
}

/// True when a received byte was overwritten before being read (RX FIFO
/// overflow). Cleared by reading the flag as usual.
pub fn rx_overflowed() bool {
    return spi.INTFLAGS.read().BUFOVF != 0;
}
