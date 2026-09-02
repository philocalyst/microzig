//! TWI0 - Two-Wire Interface (I2C-compatible).
//!
//! DS40002413 section 29 "TWI - Two-Wire Interface", page 421.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=421
//!
//! Route the pins with `portmux.set_twi0` first. The default position is
//! SDA PA2 / SCL PA3, with the dual-mode client on PC2/PC3.
//!
//! Simultaneous host+client on separate pins is a package capability
//! (peripheral overview note 1) and requires Dual mode: set
//! `ClientConfig.dual_mode` so `DUALCTRL.ENABLE` is written after FMPEN/
//! SDAHOLD (DS40002413 section 29.3.3.4).

const microzig = @import("microzig");

const twi = microzig.chip.peripherals.TWI0;
const gen = microzig.chip.types.peripherals.TWI;

const serial_math = @import("serial_math.zig");

/// MSTATUS.BUSSTATE - the host's view of the bus.
///
/// DS40002413 section 29.3.2.2.2 "TWI Bus State Logic", page 425: after enable
/// the state is UNKNOWN and the host will not start a transfer, so
/// `force_idle()` has to run once during initialization.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=425
pub const BusState = gen.TWI_BUSSTATE;

/// CTRLA.SDAHOLD - hold time on SDA after SCL falls.
pub const SdaHold = gen.TWI_SDAHOLD;

/// MCTRLA.TIMEOUT - inactive bus time-out, required for SMBus.
pub const Timeout = gen.TWI_TIMEOUT;

/// MCTRLB.MCMD - what the host should do next.
pub const Command = gen.TWI_MCMD;

/// Failure modes reported from MSTATUS during host transfers.
pub const Error = error{
    /// The addressed client did not acknowledge.
    Nack,
    /// Arbitration was lost to another host.
    ArbitrationLost,
    /// Illegal START/STOP seen on the bus.
    BusError,
};

/// Host configuration; bus speed follows from `clk_per_hz` and
/// `scl_hz`, including rise-time compensation.
pub const Config = struct {
    /// Target SCL frequency.
    scl_hz: u32 = 100_000,
    /// Peripheral clock the TWI runs from.
    clk_per_hz: u32,
    /// Bus rise time in nanoseconds, set by the pull-ups and bus capacitance.
    /// It appears directly in the baud formula, so a wrong value here shows up
    /// as a wrong SCL frequency.
    rise_time_ns: u32 = 100,
    sda_hold: SdaHold = .OFF,
    timeout: Timeout = .DISABLED,
    /// CTRLA.FMPEN - Fast mode plus (1 MHz).
    fast_mode_plus: bool = false,
    /// MCTRLA.SMEN - reading MDATA automatically issues the next command.
    smart_mode: bool = false,
};

/// Compute MBAUD.
///
/// DS40002413 section 29.3.2.2.1 "Clock Generation", page 424 gives
/// `f_SCL = f_CLK_PER / (10 + 2*BAUD + f_CLK_PER * T_RISE)`, which rearranges
/// to the expression below. Returns null when the target is out of reach --
/// too fast to represent, or so slow that BAUD overflows a byte.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=424
pub fn baud_register(clk_per_hz: u32, scl_hz: u32, rise_time_ns: u32) ?u8 {
    // Pure math lives in serial_math so host tests pin the ceil-divide that
    // keeps f_SCL equal-or-less than the mode limit (section 29.3.2.2.1).
    return serial_math.twi_baud(clk_per_hz, scl_hz, rise_time_ns);
}

/// Configure and enable the host.
///
/// DS40002413 section 29.3.2.1.1 "Host Initialization", page 423.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=423
pub fn configure(config: Config) error{UnreachableBaudRate}!void {
    const baud = baud_register(config.clk_per_hz, config.scl_hz, config.rise_time_ns) orelse
        return error.UnreachableBaudRate;

    twi.MCTRLA.write(.{
        .ENABLE = 0,
        .SMEN = 0,
        .TIMEOUT = config.timeout,
        .QCEN = 0,
        .WIEN = 0,
        .RIEN = 0,
    });

    // TWI.CTRLA carries only signal conditioning -- there is no ENABLE bit
    // here; host enable lives in MCTRLA, client enable in SCTRLA/DUALCTRL.
    twi.CTRLA.write(.{
        .FMPEN = if (config.fast_mode_plus) .ON else .OFF,
        .SDAHOLD = config.sda_hold,
        .SDASETUP = .@"4CYC",
        .INPUTLVL = .I2C,
    });

    twi.MBAUD.modify(.{ .BAUD = baud });

    // Host enable with Smart Mode as configured; the client side stays off.
    twi.MCTRLA.write(.{
        .ENABLE = 1,
        .SMEN = @intFromBool(config.smart_mode),
        .TIMEOUT = config.timeout,
        .QCEN = 0,
        .WIEN = 0,
        .RIEN = 0,
    });

    force_idle();
}

/// Declare the bus idle.
///
/// Required once after enabling the host: BUSSTATE comes out of reset as
/// UNKNOWN and no transfer will start until it is IDLE.
pub fn force_idle() void {
    twi.MSTATUS.modify(.{ .BUSSTATE = .IDLE });
}

/// Disable host operation; a configured client stays enabled.
pub fn disable() void {
    twi.MCTRLA.modify(.{ .ENABLE = 0 });
}

/// Read MSTATUS.BUSSTATE.
pub fn bus_state() BusState {
    return twi.MSTATUS.read().BUSSTATE;
}

fn check_status() Error!void {
    const s = twi.MSTATUS.read();
    if (s.ARBLOST != 0 or s.BUSERR != 0) {
        // Both flags are write-one-to-clear; leaving them set would make
        // every later transfer see a stale fault. BUSSTATE is rewritten as
        // UNKNOWN, matching its read-back value, and the APIF/WIF/RIF
        // strobes are left at their read values so this clear stays scoped
        // to the error flags.
        twi.MSTATUS.modify(.{ .ARBLOST = 1, .BUSERR = 1 });
        if (s.ARBLOST != 0) return error.ArbitrationLost;
        return error.BusError;
    }
}

/// Wait for the write or read interrupt flag, whichever the last operation
/// should raise.
fn wait_flags() @TypeOf(twi.MSTATUS.read()) {
    while (true) {
        const status = twi.MSTATUS.read();
        if (status.WIF != 0 or status.RIF != 0) return status;
    }
}

/// The R/W bit of the address byte.
pub const Direction = enum(u1) {
    write = 0,
    read = 1,
};

/// Send a START and the 7-bit address with the read/write bit.
///
/// DS40002413 section 29.3.2.2.3 "Transmitting Address Packets", page 426.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=426
pub fn start(address: u7, direction: Direction) Error!void {
    twi.MADDR.write(.{ .ADDR = (@as(u8, address) << 1) | @backingInt(direction) });
    const status = wait_flags();
    try check_status();
    // RXACK is only meaningful for the write direction; on a read the client
    // acknowledging the address is implied by RIF.
    if (direction == .write and status.RXACK != 0) return error.Nack;
}

/// Shift out one data byte and check the client's acknowledge.
pub fn write_byte(byte: u8) Error!void {
    twi.MDATA.write(.{ .DATA = byte });
    const status = wait_flags();
    try check_status();
    if (status.RXACK != 0) return error.Nack;
}

/// Read one byte. `last` sends NACK instead of ACK, which tells the client to
/// stop sending.
pub fn read_byte(last: bool) Error!u8 {
    const status = wait_flags();
    try check_status();
    const byte = twi.MDATA.read().DATA;

    // ACKACT selects what the *next* command sends; set it before issuing the
    // receive command. Stored through write_raw -- the equivalent structured
    // store to MCTRLB trips an LLVM-AVR bitcode-emission bug in this
    // toolchain ("Invalid integer const record"). Bits: MCMD [1:0],
    // ACKACT bit 2, FLUSH bit 3.
    const mctrlb: u8 = @backingInt(gen.TWI_MCMD.RECVTRANS) |
        (@as(u8, @backingInt(if (last) gen.TWI_ACKACT.NACK else gen.TWI_ACKACT.ACK)) << 2);
    twi.MCTRLB.write_raw(mctrlb);
    _ = status;
    return byte;
}

/// Issue STOP and release the bus.
pub fn stop() void {
    // Same write_raw workaround as in read_byte: MCMD = STOP, ACKACT = ACK.
    twi.MCTRLB.write_raw(@backingInt(gen.TWI_MCMD.STOP));
}

// -- Convenience transactions ------------------------------------------------

/// Write a buffer to a client, then STOP.
pub fn write(address: u7, bytes: []const u8) Error!void {
    errdefer stop();
    try start(address, .write);
    for (bytes) |byte| try write_byte(byte);
    stop();
}

/// Read into a buffer from a client, then STOP.
pub fn read(address: u7, buffer: []u8) Error!void {
    if (buffer.len == 0) return;
    errdefer stop();
    try start(address, .read);
    for (buffer, 0..) |*byte, i| {
        byte.* = try read_byte(i + 1 == buffer.len);
    }
    stop();
}

/// The register-read idiom: write `bytes`, repeated START, then read.
pub fn write_read(address: u7, bytes: []const u8, buffer: []u8) Error!void {
    errdefer stop();
    try start(address, .write);
    for (bytes) |byte| try write_byte(byte);
    try start(address, .read);
    for (buffer, 0..) |*byte, i| {
        byte.* = try read_byte(i + 1 == buffer.len);
    }
    stop();
}

// -- Client ------------------------------------------------------------------
//
// DS40002413 section 29.3.2.3 "TWI Client Operation", page 429.
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=429
//
// The client is interrupt-driven by nature: the hardware stretches SCL the
// moment it needs software attention (address match or a data byte), and
// holds it until the handler acts. The flow for each event is always: read
// SSTATUS, act on SDATA, clear the flag with an SCMD.

/// SCTRLB command byte: MCMD = RESPONSE (acknowledge and clock the next
/// byte), ACKACT = ACK. Stored through write_raw -- structured stores to the
/// MCTRLB/SCTRLB command registers trip an LLVM-AVR bitcode-emission bug in
/// this toolchain ("Invalid integer const record").
const response_cmd: u8 = @backingInt(gen.TWI_SCMD.RESPONSE);

/// Clear named W1C flags in SSTATUS via read-modify-write (the register's
/// fields carry no default values, so partial literals do not compile).
fn clear_client_flags(comptime names: anytype) void {
    var status = twi.SSTATUS.read();
    inline for (@typeInfo(@TypeOf(names)).@"struct".field_names) |name| {
        @field(status, name) = 1;
    }
    twi.SSTATUS.write(status);
}

/// Client configuration.
pub const ClientConfig = struct {
    /// This device's 7-bit address (unshifted; the R/W bit is added by
    /// hardware).
    address: u7,
    /// Address mask: bits set here are "don't care" when matching, which lets
    /// one firmware answer a range of addresses.
    address_mask: u7 = 0,
    /// Respond to the general call address 0x00 as well.
    respond_to_general_call: bool = false,
    sda_hold: SdaHold = .OFF,
    /// DUALCTRL.FMPEN when `dual_mode` is set. Ignored for shared-pin client
    /// (CTRLA.FMPEN from `configure` applies instead).
    fast_mode_plus: bool = false,
    smart_mode: bool = false,
    /// SCTRLA.PMEN - address recognition mode; used together with
    /// `address_mask`.
    promiscuous: bool = false,
    /// Enable Dual mode (DUALCTRL.ENABLE): client signal conditioning comes
    /// from DUALCTRL and the client rides the PORTMUX dual-mode pins while
    /// the host keeps the CTRLA pins. Required for simultaneous host+client
    /// on separate buses (DS40002413 section 29.3.3.4; peripheral overview
    /// note 1). Leave false for a shared-pin client on the host's wires.
    dual_mode: bool = false,
    enable_data_interrupt: bool = true,
    enable_address_interrupt: bool = true,
    enable_stop_interrupt: bool = false,
};

/// Enable the client.
///
/// Shared-pin client (`dual_mode = false`): SCTRLA enables the client on the
/// same wires CTRLA conditions for the host.
///
/// Dual mode (`dual_mode = true`): CTRLA keeps configuring the host pins and
/// DUALCTRL configures the client on the PORTMUX dual-mode pins so host and
/// client run simultaneously on separate buses (DS40002413 section 29.3.3.4
/// "Dual Mode", page 432; peripheral overview note 1). FMPEN/SDAHOLD are
/// programmed before DUALCTRL.ENABLE, as the datasheet requires.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=432
/// https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-US-8/GUID-F94E51A5-03D0-474D-820B-5DF1CA77A1BD.html
pub fn configure_client(config: ClientConfig) void {
    const gce: u8 = @intFromBool(config.respond_to_general_call);
    twi.SADDR.write(.{ .ADDR = (@as(u8, config.address) << 1) | gce });
    twi.SADDRMASK.write(.{
        .ADDREN = @intFromBool(config.address_mask != 0),
        .ADDRMASK = config.address_mask,
    });
    // Conditioning first with ENABLE clear; raise Dual-mode ENABLE last.
    twi.DUALCTRL.write(.{
        .ENABLE = 0,
        .FMPEN = if (config.fast_mode_plus) .ON else .OFF,
        .SDAHOLD = config.sda_hold,
        .INPUTLVL = .I2C,
    });
    twi.SCTRLA.write(.{
        .ENABLE = 0,
        .SMEN = @intFromBool(config.smart_mode),
        .PMEN = @intFromBool(config.promiscuous),
        .PIEN = @intFromBool(config.enable_stop_interrupt),
        .APIEN = @intFromBool(config.enable_address_interrupt),
        .DIEN = @intFromBool(config.enable_data_interrupt),
    });
    twi.SCTRLA.modify(.{ .ENABLE = 1 });
    if (config.dual_mode) {
        twi.DUALCTRL.modify(.{ .ENABLE = 1 });
    }
}

/// Disable client operation; the host side keeps running.
/// Also clears DUALCTRL.ENABLE so a prior Dual-mode client releases its pins.
pub fn disable_client() void {
    twi.SCTRLA.modify(.{ .ENABLE = 0 });
    twi.DUALCTRL.modify(.{ .ENABLE = 0 });
}

/// One client event, decoded from SSTATUS. Reuses the host-side `Direction`
/// for the R/W bit so call sites switch on one vocabulary.
pub const ClientEvent = union(enum) {
    /// Address match: the host wants to write us bytes or read from us.
    addressed: Direction,
    /// A data byte arrived (host -> client).
    data: u8,
    /// Our previously queued byte was shifted out (host <- client); queue
    /// another with `put_byte`.
    sent,
    /// The host sent STOP.
    stop,
};

/// Poll for and dispatch one client event, blocking until something happens.
///
/// Interrupt handlers can reuse the same decoding by reading SSTATUS directly;
/// this exists so polled designs are one call deep.
pub fn wait_event() Error!ClientEvent {
    while (true) {
        const status = twi.SSTATUS.read();

        if (status.BUSERR != 0) return error.BusError;
        if (status.COLL != 0) {
            // Collision while we were transmitting; drop our queued byte.
            // W1C bits: COLL | APIF | DIF.
            twi.SSTATUS.write_raw(0xc8);
            return error.ArbitrationLost;
        }

        if (status.APIF != 0) {
            if (status.AP == .ADR) {
                // Address match: ACK it and clock the next byte by issuing
                // RESPONSE (SCMD=3), which also clears APIF.
                twi.SCTRLB.write_raw(response_cmd);
                return .{ .addressed = @fromBackingInt(@intCast(status.DIR)) };
            }
            // Stop condition.
            twi.SSTATUS.write_raw(0x40); // W1C: APIF
            return .stop;
        }

        if (status.DIF != 0) {
            if (status.DIR == 0) {
                // Host writes to us: read the byte, then ACK it with the same
                // RESPONSE command (clears DIF).
                const byte = twi.SDATA.read().DATA;
                twi.SCTRLB.write_raw(response_cmd);
                return .{ .data = byte };
            }
            // Host reads from us: our queued byte left the shift register.
            return .sent;
        }
    }
}

/// Queue one byte for transmission after an `addressed = .read` match.
pub fn put_byte(byte: u8) void {
    twi.SDATA.write(.{ .DATA = byte });
}

/// Clock-hold state: true while the client is stretching SCL waiting for
/// software.
pub fn clock_held() bool {
    return twi.SSTATUS.read().CLKHOLD != 0;
}
