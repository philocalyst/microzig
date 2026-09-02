//! USART0 / USART1.
//!
//! DS40002413 section 27 "USART", page 370.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=370
//!
//! Both instances share one implementation; `Usart.usart0` / `Usart.usart1`
//! name them. Note that on the 20-pin package USART1's default pin position
//! has no TxD pad, so `portmux.Usart1.ALT2` is the one to use for a full
//! two-wire link.

const std = @import("std");
const microzig = @import("microzig");
const Io = std.Io;

const chip = microzig.chip.peripherals;
const gen = microzig.chip.types.peripherals.USART;

fn instance(comptime id: u1) *volatile gen {
    return switch (id) {
        0 => chip.USART0,
        1 => chip.USART1,
    };
}

/// CTRLC.CMODE - the USART's overall personality. Encodings re-exported from
/// the generated layer.
pub const Mode = gen.USART_CMODE;

/// CTRLC.CHSIZE.
pub const CharacterSize = gen.USART_NORMAL_CHSIZE;

/// CTRLC.PMODE.
pub const Parity = gen.USART_NORMAL_PMODE;

/// CTRLC.SBMODE.
pub const StopBits = gen.USART_NORMAL_SBMODE;

/// CTRLB.RXMODE. Beyond picking the oversampling rate, this also selects the
/// two auto-baud modes. Encodings re-exported from the generated layer.
pub const ReceiverMode = gen.USART_RXMODE;

/// Samples per bit for a receiver mode -- the `S` term in the baud formula.
pub fn oversampling(m: ReceiverMode) u16 {
    return switch (m) {
        .CLK2X => 8,
        else => 16,
    };
}

/// Formatting and baud requirements; the clock is explicit because
/// nothing on the device reports CLK_PER back to software.
pub const Config = struct {
    baud_rate: u32 = 115_200,
    /// Peripheral clock the USART is running from. Needed because the baud
    /// register is a ratio, and nothing on the device reports CLK_PER.
    clk_per_hz: u32,
    mode: Mode = .ASYNCHRONOUS,
    character_size: CharacterSize = .@"8BIT",
    parity: Parity = .DISABLED,
    stop_bits: StopBits = .@"1BIT",
    receiver_mode: ReceiverMode = .NORMAL,
    enable_tx: bool = true,
    enable_rx: bool = true,
    /// CTRLB.ODME - open-drain TxD, for a one-wire half-duplex bus.
    /// DS40002413 section 27.3.3.2.6 "Half-Duplex Operation", page 381.
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
    const samples = oversampling(receiver_mode);
    const denominator = @as(u64, samples) * baud_rate;
    // Round to nearest rather than truncating; at low clocks the difference is
    // a whole percent of baud error.
    const value = (@as(u64, clk_per_hz) * 64 + denominator / 2) / denominator;
    if (value < 64 or value > 0xFFFF) return null;
    return @intCast(value);
}

/// Typed driver for USART0 or USART1.
/// Invalid ids are compile errors listing the instances that exist.
pub fn Instance(comptime id: u1) type {
    const u = instance(id);

    return struct {
        const This = @This();

        /// Configure and enable the USART.
        ///
        /// DS40002413 section 27.3.1 "Initialization", page 371. Returns
        /// `error.UnreachableBaudRate` if the requested rate cannot be
        /// expressed at `config.clk_per_hz` -- silently running at the wrong
        /// speed is worse than refusing.
        pub fn configure(config: Config) error{UnreachableBaudRate}!void {
            const baud = baud_register(config.clk_per_hz, config.baud_rate, config.receiver_mode) orelse
                return error.UnreachableBaudRate;

            u.CTRLB.write(.{
                .MPCM = 0,
                .RXMODE = config.receiver_mode,
                .ODME = @intFromBool(config.open_drain),
                .SFDEN = 0,
                .TXEN = 0,
                .RXEN = 0,
            });

            u.CTRLA.write(.{
                .RS485 = @fromBackingInt(@intCast(@intFromBool(config.rs485))),
                .ABEIE = 0,
                .LBME = @intFromBool(config.loopback),
                .RXSIE = 0,
                .DREIE = 0,
                .TXCIE = 0,
                .RXCIE = 0,
            });

            u.CTRLB.write(.{
                .MPCM = 0,
                .RXMODE = config.receiver_mode,
                .ODME = @intFromBool(config.open_drain),
                .SFDEN = 0,
                .TXEN = @intFromBool(config.enable_tx),
                .RXEN = @intFromBool(config.enable_rx),
            });

            u.CTRLC.write(.{
                .CHSIZE = config.character_size,
                .SBMODE = config.stop_bits,
                .PMODE = config.parity,
                .CMODE = config.mode,
            });

            u.BAUD = baud;
        }

        /// Change the baud rate on a running USART.
        pub fn set_baud_rate(
            clk_per_hz: u32,
            baud_rate: u32,
            receiver_mode: ReceiverMode,
        ) error{UnreachableBaudRate}!void {
            const baud = baud_register(clk_per_hz, baud_rate, receiver_mode) orelse
                return error.UnreachableBaudRate;
            u.BAUD = baud;
        }

        pub fn disable() void {
            u.CTRLB.write(.{
                .MPCM = 0,
                .RXMODE = .NORMAL,
                .ODME = 0,
                .SFDEN = 0,
                .TXEN = 0,
                .RXEN = 0,
            });
        }

        // -- Transmit --------------------------------------------------------

        /// True when TXDATA can accept another byte.
        pub fn writable() bool {
            return u.STATUS.read().DREIF != 0;
        }

        pub fn write_byte(byte: u8) void {
            while (!writable()) {}
            u.TXDATAL.write(.{ .DATA = byte });
        }

        pub fn write_all(bytes: []const u8) void {
            for (bytes) |byte| write_byte(byte);
        }

        /// Write a 9-bit character. The high byte must be written before the
        /// low byte, because writing TXDATAL is what starts the transmission.
        pub fn write_byte9(value: u9) void {
            while (!writable()) {}
            u.TXDATAH.write(.{ .DATA8 = @intCast(value >> 8) });
            u.TXDATAL.write(.{ .DATA = @truncate(value) });
        }

        /// Block until the last bit has actually left the shift register,
        /// which is what you want before disabling the transmitter or entering
        /// sleep. DS40002413 section 27.3.2.3.1 "Disabling the Transmitter",
        /// page 374.
        pub fn flush() void {
            while (u.STATUS.read().TXCIF == 0) {}
            u.STATUS.write(.{ .TXCIF = 1, .DREIF = 0, .RXCIF = 0, .RXSIF = 0, .ISFIF = 0, .BDF = 0, .WFB = 0 });
        }

        // -- Receive ---------------------------------------------------------

        pub fn readable() bool {
            return u.STATUS.read().RXCIF != 0;
        }

        pub fn read_byte() u8 {
            while (!readable()) {}
            return u.RXDATAL.read().DATA;
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
        /// RXDATAH must be read *before* RXDATAL -- reading the low byte is
        /// what pops the FIFO.
        /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=375
        pub fn read_byte_checked() ReceiveError!u8 {
            while (!readable()) {}
            const high = u.RXDATAH.read();
            const low = u.RXDATAL.read().DATA;
            if (high.BUFOVF != 0) return error.Overflow;
            if (high.FERR != 0) return error.Framing;
            if (high.PERR != 0) return error.Parity;
            return low;
        }

        /// Read a 9-bit character, high byte first as the hardware requires.
        pub fn read_byte9() u9 {
            while (!readable()) {}
            const high = u.RXDATAH.read();
            const low = u.RXDATAL.read().DATA;
            return (@as(u9, high.DATA8) << 8) | low;
        }

        pub fn read_all(buffer: []u8) void {
            for (buffer) |*byte| byte.* = read_byte();
        }

        /// Discard anything already received.
        ///
        /// DS40002413 section 27.3.2.4.3 "Flushing the Receive Buffer",
        /// page 375.
        pub fn flush_rx() void {
            while (readable()) {
                _ = u.RXDATAL.read_raw();
            }
        }

        // -- Interrupts ------------------------------------------------------

        pub fn enable_rx_interrupt() void {
            u.CTRLA.modify(.{ .RXCIE = 1 });
        }

        pub fn enable_tx_complete_interrupt() void {
            u.CTRLA.modify(.{ .TXCIE = 1 });
        }

        pub fn enable_data_register_empty_interrupt() void {
            u.CTRLA.modify(.{ .DREIE = 1 });
        }

        pub fn disable_interrupts() void {
            u.CTRLA.modify(.{ .RXCIE = 0, .TXCIE = 0, .DREIE = 0 });
        }

        // -- std.Io integration ----------------------------------------------

        /// A blocking writer, so formatters can write straight to the port.
        pub fn writer(buffer: []u8) Writer {
            return .init(This, buffer);
        }

        pub const Writer = struct {
            interface: Io.Writer,
            usart: type,

            pub fn init(usart: type, buffer: []u8) Writer {
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

        /// Blocking `std.Io.Reader` over this instance, mirroring the writer
        /// half and the shape the other ports shipped for #1008. Receive
        /// errors (parity/framing/overflow) surface as `error.ReadFailed`,
        /// matching nrf5x.
        pub fn reader(buffer: []u8) Reader {
            return .{ .interface = .{
                .buffer = buffer,
                .seek = 0,
                .end = 0,
                .vtable = &.{ .stream = Reader.stream },
            } };
        }

        const Reader = struct {
            interface: Io.Reader,

            fn stream(r: *Io.Reader, w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
                _ = r;
                return switch (limit) {
                    .nothing => 0,
                    else => {
                        const byte = This.read_byte_checked() catch return error.ReadFailed;
                        try w.writeByte(byte);
                        return 1;
                    },
                };
            }
        };
    };
}

/// Namespace preserving the classic `usart.Usart.usart0` spelling; each field
/// is the instance's typed namespace.
pub const Usart = struct {
    pub const usart0 = Instance(0);
    pub const usart1 = Instance(1);
};
