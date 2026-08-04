//! TWI0 - Two-Wire Interface (I2C-compatible).
//!
//! DS40002413 section 29 "TWI - Two-Wire Interface", page 421.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=421
//!
//! Route the pins with `portmux.set_twi0` first. The default position is
//! SDA PA2 / SCL PA3, with the dual-mode client on PC2/PC3.

const regs = @import("registers.zig");

/// MSTATUS.BUSSTATE - the host's view of the bus.
///
/// DS40002413 section 29.3.2.2.2 "TWI Bus State Logic", page 425: after enable
/// the state is UNKNOWN and the host will not start a transfer, so
/// `force_idle()` has to run once during initialization.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=425
pub const BusState = enum(u8) {
    unknown = 0x0,
    idle = 0x1,
    owner = 0x2,
    busy = 0x3,
};

/// CTRLA.SDAHOLD - hold time on SDA after SCL falls.
pub const SdaHold = enum(u8) {
    off = 0x0,
    /// ~50 ns, enough for most I2C devices.
    hold50ns = 0x1,
    /// ~300 ns, for SMBus.
    hold300ns = 0x2,
    hold500ns = 0x3,
};

/// MCTRLA.TIMEOUT - inactive bus time-out, required for SMBus.
pub const Timeout = enum(u8) {
    disabled = 0x0,
    us50 = 0x1,
    us100 = 0x2,
    us200 = 0x3,
};

/// MCTRLB.MCMD - what the host should do next.
pub const Command = enum(u8) {
    none = 0x0,
    /// Repeated START.
    repeat_start = 0x1,
    /// Receive or transmit the next byte.
    receive = 0x2,
    /// STOP.
    stop = 0x3,
};

pub const Error = error{
    /// The addressed client did not acknowledge.
    Nack,
    /// Arbitration was lost to another host.
    ArbitrationLost,
    /// Illegal START/STOP seen on the bus.
    BusError,
};

pub const Config = struct {
    /// Target SCL frequency.
    scl_hz: u32 = 100_000,
    /// Peripheral clock the TWI runs from.
    clk_per_hz: u32,
    /// Bus rise time in nanoseconds, set by the pull-ups and bus capacitance.
    /// It appears directly in the baud formula, so a wrong value here shows up
    /// as a wrong SCL frequency.
    rise_time_ns: u32 = 100,
    sda_hold: SdaHold = .off,
    timeout: Timeout = .disabled,
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
    if (scl_hz == 0) return null;

    // f_CLK_PER * T_RISE, with T_RISE in nanoseconds, in units of clock cycles.
    const rise_cycles = (@as(u64, clk_per_hz) * rise_time_ns) / 1_000_000_000;
    const total = @as(u64, clk_per_hz) / scl_hz;
    if (total < 10 + rise_cycles) return null;

    const value = (total - 10 - rise_cycles) / 2;
    if (value > 0xFF) return null;
    return @intCast(value);
}

/// Configure and enable the host.
///
/// DS40002413 section 29.3.2.1.1 "Host Initialization", page 423.
pub fn configure(config: Config) error{UnreachableBaudRate}!void {
    const baud = baud_register(config.clk_per_hz, config.scl_hz, config.rise_time_ns) orelse
        return error.UnreachableBaudRate;

    regs.write(regs.twi0.mctrla, 0);

    var ctrla: u8 = @as(u8, @intFromEnum(config.sda_hold)) << 2;
    if (config.fast_mode_plus) ctrla |= regs.bit(1);
    regs.write(regs.twi0.ctrla, ctrla);

    regs.write(regs.twi0.mbaud, baud);

    var mctrla: u8 = regs.bit(regs.twi0.menable) | (@as(u8, @intFromEnum(config.timeout)) << 2);
    if (config.smart_mode) mctrla |= regs.bit(regs.twi0.smen);
    regs.write(regs.twi0.mctrla, mctrla);

    force_idle();
}

/// Declare the bus idle.
///
/// Required once after enabling the host: BUSSTATE comes out of reset as
/// UNKNOWN and no transfer will start until it is IDLE.
pub fn force_idle() void {
    regs.write(regs.twi0.mstatus, @intFromEnum(BusState.idle));
}

pub fn disable() void {
    regs.write(regs.twi0.mctrla, 0);
}

pub fn bus_state() BusState {
    return @enumFromInt(regs.read(regs.twi0.mstatus) & 0x03);
}

fn check_status(status: u8) Error!void {
    if ((status & regs.bit(regs.twi0.arblost)) != 0) return error.ArbitrationLost;
    if ((status & regs.bit(regs.twi0.buserr)) != 0) return error.BusError;
}

/// Wait for the write or read interrupt flag, whichever the last operation
/// should raise.
fn wait_flags() u8 {
    const wanted = regs.bit(regs.twi0.wif) | regs.bit(regs.twi0.rif);
    while (true) {
        const status = regs.read(regs.twi0.mstatus);
        if ((status & wanted) != 0) return status;
    }
}

/// Send a START and the 7-bit address with the read/write bit.
///
/// DS40002413 section 29.3.2.2.3 "Transmitting Address Packets", page 426.
pub fn start(address: u7, direction: Direction) Error!void {
    regs.write(
        regs.twi0.maddr,
        (@as(u8, address) << 1) | @intFromEnum(direction),
    );
    const status = wait_flags();
    try check_status(status);
    // RXACK is only meaningful for the write direction; on a read the client
    // acknowledging the address is implied by RIF.
    if (direction == .write and (status & regs.bit(regs.twi0.rxack)) != 0) {
        return error.Nack;
    }
}

/// The R/W bit of the address byte.
pub const Direction = enum(u1) {
    write = 0,
    read = 1,
};

pub fn write_byte(byte: u8) Error!void {
    regs.write(regs.twi0.mdata, byte);
    const status = wait_flags();
    try check_status(status);
    if ((status & regs.bit(regs.twi0.rxack)) != 0) return error.Nack;
}

/// Read one byte. `last` sends NACK instead of ACK, which tells the client to
/// stop sending.
pub fn read_byte(last: bool) Error!u8 {
    const status = wait_flags();
    try check_status(status);
    const byte = regs.read(regs.twi0.mdata);

    // ACKACT selects what the *next* command sends; set it before issuing the
    // receive command.
    var mctrlb: u8 = @intFromEnum(Command.receive);
    if (last) mctrlb |= regs.bit(2); // ACKACT = NACK
    regs.write(regs.twi0.mctrlb, mctrlb);
    return byte;
}

pub fn stop() void {
    regs.write(regs.twi0.mctrlb, @intFromEnum(Command.stop));
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
