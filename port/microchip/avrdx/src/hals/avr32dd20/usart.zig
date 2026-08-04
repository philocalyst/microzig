//! USART0 / USART1.
//!
//! DS40002413 section 27 "USART", page 370.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=370
//!
//! Both instances share one implementation; `Usart.usart0` / `Usart.usart1`
//! name them. Note that on the 20-pin package USART1's default pin position
//! has no TxD pad, so `portmux.Usart1.alt2` is the one to use for a full
//! two-wire link.

const std = @import("std");
const Io = std.Io;
const regs = @import("registers.zig");

/// CTRLC.CMODE - the USART's overall personality.
pub const Mode = enum(u8) {
    asynchronous = 0x0,
    /// Clocked from XCK.
    synchronous = 0x1,
    /// IrDA pulse coding.
    ircom = 0x2,
    /// SPI host, using XCK as SCK. See `portmux` for the pin positions.
    spi_host = 0x3,
};

/// CTRLC.CHSIZE.
pub const CharacterSize = enum(u8) {
    bits5 = 0x0,
    bits6 = 0x1,
    bits7 = 0x2,
    bits8 = 0x3,
    /// 9-bit, low byte read first.
    bits9_low_first = 0x6,
    /// 9-bit, high byte read first.
    bits9_high_first = 0x7,
};

/// CTRLC.PMODE.
pub const Parity = enum(u8) {
    none = 0x0,
    even = 0x2,
    odd = 0x3,
};

/// CTRLC.SBMODE.
pub const StopBits = enum(u8) {
    one = 0x0,
    two = 0x1,
};

/// CTRLB.RXMODE. Beyond picking the oversampling rate, this also selects the
/// two auto-baud modes.
pub const ReceiverMode = enum(u8) {
    /// 16x oversampling.
    normal = 0x0,
    /// 8x oversampling: double the maximum baud rate at half the noise
    /// tolerance. DS40002413 section 27.3.3.2.4 "Double-Speed Operation",
    /// page 380.
    double_speed = 0x1,
    /// Measure the baud rate from a sync field.
    auto_baud = 0x2,
    /// Auto-baud constrained to the LIN sync byte.
    lin_auto_baud = 0x3,

    /// Samples per bit, the `S` term in the baud rate formula.
    pub fn oversampling(m: ReceiverMode) u16 {
        return switch (m) {
            .double_speed => 8,
            else => 16,
        };
    }
};

pub const Config = struct {
    baud_rate: u32 = 115_200,
    /// Peripheral clock the USART is running from. Needed because the baud
    /// register is a ratio, and nothing on the device reports CLK_PER.
    clk_per_hz: u32,
    mode: Mode = .asynchronous,
    character_size: CharacterSize = .bits8,
    parity: Parity = .none,
    stop_bits: StopBits = .one,
    receiver_mode: ReceiverMode = .normal,
    enable_tx: bool = true,
    enable_rx: bool = true,
    /// CTRLB.ODME - open-drain TxD, for a one-wire half-duplex bus.
    /// DS40002413 section 27.3.3.2.6.1 "One-Wire Mode", page 381.
    open_drain: bool = false,
    /// CTRLA.RS485 - drive XDIR as a transceiver direction signal.
    rs485: bool = false,
    /// CTRLA.LBME - internal loop-back, for self-test.
    loopback: bool = false,
};

/// Compute the BAUD register value.
///
/// DS40002413 section 27.3.2.2.1 "The Fractional Baud Rate Generator",
/// page 373: BAUD is a 16-bit value with 6 fractional bits, so
/// `BAUD = 64 * f_CLK_PER / (S * f_BAUD)` where S is the oversampling rate.
/// The register must be at least 64 (i.e. a divider of at least 1).
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=373
///
/// Returns null when the request is unreachable at this clock.
pub fn baud_register(clk_per_hz: u32, baud_rate: u32, receiver_mode: ReceiverMode) ?u16 {
    if (baud_rate == 0) return null;
    const samples = receiver_mode.oversampling();
    const denominator = @as(u64, samples) * baud_rate;
    // Round to nearest rather than truncating; at low clocks the difference is
    // a whole percent of baud error.
    const value = (@as(u64, clk_per_hz) * 64 + denominator / 2) / denominator;
    if (value < 64 or value > 0xFFFF) return null;
    return @intCast(value);
}

pub const Usart = struct {
    base: u16,

    /// Default pins TxD PA0, RxD PA1 (see `portmux.Usart0`).
    pub const usart0: Usart = .{ .base = regs.usart0_base };
    /// Default position has RxD PC1 only; use `portmux.Usart1.alt2` for
    /// TxD PD6 / RxD PD7.
    pub const usart1: Usart = .{ .base = regs.usart1_base };

    fn reg(u: Usart, offset: u16) u16 {
        return u.base + offset;
    }

    /// Configure and enable the USART.
    ///
    /// DS40002413 section 27.3.1 "Initialization", page 371. Returns
    /// `error.UnreachableBaudRate` if the requested rate cannot be expressed
    /// at `config.clk_per_hz` -- silently running at the wrong speed is worse
    /// than refusing.
    pub fn configure(u: Usart, config: Config) error{UnreachableBaudRate}!void {
        const baud = baud_register(config.clk_per_hz, config.baud_rate, config.receiver_mode) orelse
            return error.UnreachableBaudRate;

        regs.write(u.reg(regs.usart_offsets.ctrlb), 0);

        regs.write(
            u.reg(regs.usart_offsets.ctrlc),
            (@as(u8, @intFromEnum(config.mode)) << 6) |
                (@as(u8, @intFromEnum(config.parity)) << 4) |
                (@as(u8, @intFromEnum(config.stop_bits)) << 3) |
                @intFromEnum(config.character_size),
        );

        regs.mem16(u.reg(regs.usart_offsets.baud)).* = baud;

        var ctrla: u8 = 0;
        if (config.rs485) ctrla |= regs.bit(regs.usart_bits.rs485);
        if (config.loopback) ctrla |= regs.bit(regs.usart_bits.lbme);
        regs.write(u.reg(regs.usart_offsets.ctrla), ctrla);

        var ctrlb: u8 = @as(u8, @intFromEnum(config.receiver_mode)) << 1;
        if (config.enable_tx) ctrlb |= regs.bit(regs.usart_bits.txen);
        if (config.enable_rx) ctrlb |= regs.bit(regs.usart_bits.rxen);
        if (config.open_drain) ctrlb |= regs.bit(regs.usart_bits.odme);
        regs.write(u.reg(regs.usart_offsets.ctrlb), ctrlb);
    }

    /// Change the baud rate on a running USART.
    pub fn set_baud_rate(
        u: Usart,
        clk_per_hz: u32,
        baud_rate: u32,
        receiver_mode: ReceiverMode,
    ) error{UnreachableBaudRate}!void {
        const baud = baud_register(clk_per_hz, baud_rate, receiver_mode) orelse
            return error.UnreachableBaudRate;
        regs.mem16(u.reg(regs.usart_offsets.baud)).* = baud;
    }

    pub fn disable(u: Usart) void {
        regs.write(u.reg(regs.usart_offsets.ctrlb), 0);
    }

    // -- Transmit ------------------------------------------------------------

    /// True when TXDATA can accept another byte.
    pub fn writable(u: Usart) bool {
        return (regs.read(u.reg(regs.usart_offsets.status)) & regs.bit(regs.usart_bits.dreif)) != 0;
    }

    pub fn write_byte(u: Usart, byte: u8) void {
        while (!u.writable()) {}
        regs.write(u.reg(regs.usart_offsets.txdatal), byte);
    }

    pub fn write_all(u: Usart, bytes: []const u8) void {
        for (bytes) |byte| u.write_byte(byte);
    }

    /// Write a 9-bit character. The high byte must be written before the low
    /// byte, because writing TXDATAL is what starts the transmission.
    pub fn write_byte9(u: Usart, value: u9) void {
        while (!u.writable()) {}
        regs.write(u.reg(regs.usart_offsets.txdatah), @intCast(value >> 8));
        regs.write(u.reg(regs.usart_offsets.txdatal), @truncate(value));
    }

    /// Block until the last bit has actually left the shift register, which is
    /// what you want before disabling the transmitter or entering sleep.
    ///
    /// DS40002413 section 27.3.2.3.1 "Disabling the Transmitter", page 374.
    pub fn flush(u: Usart) void {
        const status = u.reg(regs.usart_offsets.status);
        while ((regs.read(status) & regs.bit(regs.usart_bits.txcif)) == 0) {}
        regs.write(status, regs.bit(regs.usart_bits.txcif));
    }

    // -- Receive -------------------------------------------------------------

    pub fn readable(u: Usart) bool {
        return (regs.read(u.reg(regs.usart_offsets.status)) & regs.bit(regs.usart_bits.rxcif)) != 0;
    }

    pub fn read_byte(u: Usart) u8 {
        while (!u.readable()) {}
        return regs.read(u.reg(regs.usart_offsets.rxdatal));
    }

    pub const ReceiveError = error{
        /// Parity did not match.
        Parity,
        /// Stop bit was not high.
        Framing,
        /// A character was lost before it could be read.
        Overflow,
    };

    /// Read a byte and report the receiver error flags.
    ///
    /// DS40002413 section 27.3.2.4.1 "Receiver Error Flags", page 375: the
    /// flags live in RXDATAH and belong to the character in RXDATAL, so
    /// RXDATAH must be read *before* RXDATAL -- reading the low byte is what
    /// pops the FIFO.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=375
    pub fn read_byte_checked(u: Usart) ReceiveError!u8 {
        while (!u.readable()) {}
        const high = regs.read(u.reg(regs.usart_offsets.rxdatah));
        const low = regs.read(u.reg(regs.usart_offsets.rxdatal));

        if ((high & 0x40) != 0) return error.Overflow; // BUFOVF
        if ((high & 0x04) != 0) return error.Framing; // FERR
        if ((high & 0x02) != 0) return error.Parity; // PERR
        return low;
    }

    /// Read a 9-bit character, high byte first as the hardware requires.
    pub fn read_byte9(u: Usart) u9 {
        while (!u.readable()) {}
        const high = regs.read(u.reg(regs.usart_offsets.rxdatah));
        const low = regs.read(u.reg(regs.usart_offsets.rxdatal));
        return (@as(u9, high & 0x01) << 8) | low;
    }

    pub fn read_all(u: Usart, buffer: []u8) void {
        for (buffer) |*byte| byte.* = u.read_byte();
    }

    /// Discard anything already received.
    ///
    /// DS40002413 section 27.3.2.4.3 "Flushing the Receive Buffer", page 375.
    pub fn flush_rx(u: Usart) void {
        while (u.readable()) {
            _ = regs.read(u.reg(regs.usart_offsets.rxdatal));
        }
    }

    // -- Interrupts ----------------------------------------------------------

    pub fn enable_rx_interrupt(u: Usart) void {
        regs.set_bits(u.reg(regs.usart_offsets.ctrla), regs.bit(regs.usart_bits.rxcie));
    }

    pub fn enable_tx_complete_interrupt(u: Usart) void {
        regs.set_bits(u.reg(regs.usart_offsets.ctrla), regs.bit(regs.usart_bits.txcie));
    }

    pub fn enable_data_register_empty_interrupt(u: Usart) void {
        regs.set_bits(u.reg(regs.usart_offsets.ctrla), regs.bit(regs.usart_bits.dreie));
    }

    pub fn disable_interrupts(u: Usart) void {
        regs.clear_bits(u.reg(regs.usart_offsets.ctrla), 0xF4);
    }

    // -- std.Io integration --------------------------------------------------

    /// A blocking writer, so `std.fmt` can format straight to the port.
    pub fn writer(u: Usart, buffer: []u8) Writer {
        return .init(u, buffer);
    }

    pub const Writer = struct {
        interface: Io.Writer,
        usart: Usart,

        pub fn init(usart: Usart, buffer: []u8) Writer {
            return .{ .usart = usart, .interface = init_interface(buffer) };
        }

        fn init_interface(buffer: []u8) Io.Writer {
            return .{ .vtable = &.{ .drain = drain }, .buffer = buffer };
        }

        fn drain(io_w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
            const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
            if (data.len == 0) return 0;

            w.usart.write_all(io_w.buffered());
            io_w.end = 0;

            var size: usize = 0;
            for (data[0 .. data.len - 1]) |buf| {
                w.usart.write_all(buf);
                size += buf.len;
            }
            for (0..splat) |_|
                w.usart.write_all(data[data.len - 1]);
            return size + splat * data[data.len - 1].len;
        }
    };
};
