//! PORTMUX - peripheral pin routing.
//!
//! DS40002413 section 17 "PORTMUX - Port Multiplexer", page 153.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=153
//!
//! Only the routings that land on a pad bonded out by the 20-pin package are
//! listed. The pin lists in each doc comment are transcribed from the
//! AVR32DD20 ATDF's PORTMUX value groups, so they describe this package
//! specifically -- several of these options reach more pins on DD28/DD32.

const regs = @import("registers.zig");

/// PORTMUX.USARTROUTEA.USART0, bits 2:0.
pub const Usart0 = enum(u8) {
    /// TxD PA0, RxD PA1, XCK PA2, XDIR PA3.
    default = 0x0,
    /// TxD PA4, RxD PA5, XCK PA6, XDIR PA7.
    alt1 = 0x1,
    /// TxD PA2, RxD PA3. No XCK or XDIR.
    alt2 = 0x2,
    /// TxD PD4, RxD PD5, XCK PD6, XDIR PD7.
    alt3 = 0x3,
    /// TxD PC1, RxD PC2, XCK PC3. No XDIR. Note these are MVIO pins.
    alt4 = 0x4,
    /// Not connected to any pin.
    none = 0x5,
};

/// PORTMUX.USARTROUTEA.USART1, bits 4:3.
pub const Usart1 = enum(u8) {
    /// RxD PC1, XCK PC2, XDIR PC3 -- there is no TxD pad for USART1 in this
    /// position on the 20-pin package, so this is receive-only.
    default = 0x0,
    /// TxD PD6, RxD PD7.
    alt2 = 0x2,
    none = 0x3,
};

/// PORTMUX.SPIROUTEA.SPI0, bits 2:0.
pub const Spi0 = enum(u8) {
    /// MOSI PA4, MISO PA5, SCK PA6, SS PA7.
    default = 0x0,
    /// MOSI PA0, MISO PA1, SS PC1. No SCK pad -- host mode only if SCK is
    /// unneeded, which in practice means this position is for client mode.
    alt3 = 0x3,
    /// MOSI PD4, MISO PD5, SCK PD6, SS PD7.
    alt4 = 0x4,
    /// MISO PC1, SCK PC2, SS PC3. No MOSI pad.
    alt5 = 0x5,
    /// MOSI PC1, MISO PC2, SCK PC3, SS PF7.
    alt6 = 0x6,
    /// Not connected to any pin; SS is driven to 1 internally.
    none = 0x7,
};

/// PORTMUX.TWIROUTEA.TWI0, bits 1:0.
pub const Twi0 = enum(u8) {
    /// SDA PA2, SCL PA3. Dual mode client: SDA PC2, SCL PC3.
    default = 0x0,
    /// SDA PA2, SCL PA3. Dual mode disabled.
    alt1 = 0x1,
    /// SDA PC2, SCL PC3. Dual mode disabled.
    alt2 = 0x2,
    /// SDA PA0, SCL PA1. Dual mode client: SDA PC2, SCL PC3.
    alt3 = 0x3,
};

/// PORTMUX.TCAROUTEA.TCA0, bits 2:0.
///
/// TCA0 routes as a block: all six waveform outputs move together, which is
/// why the values name a port rather than an "alt" index.
pub const Tca0 = enum(u8) {
    /// WO0..WO5 on PA0..PA5.
    porta = 0x0,
    /// WO1..WO3 on PC1..PC3. WO0, WO4 and WO5 have no pad here.
    portc = 0x2,
    /// WO4 on PD4 and WO5 on PD5 only.
    portd = 0x3,
};

/// PORTMUX.TCDROUTEA.TCD0, bits 2:0.
pub const Tcd0 = enum(u8) {
    /// WOA PA4, WOB PA5, WOC PA6, WOD PA7.
    default = 0x0,
    /// WOA PA4, WOB PA5, WOC PD4, WOD PD5.
    alt4 = 0x4,
};

/// PORTMUX.EVSYSROUTEA.EVOUTA, bit 0.
pub const EventOutputA = enum(u8) {
    /// PA2.
    default = 0x0,
    /// PA7.
    alt1 = 0x1,
};

/// PORTMUX.EVSYSROUTEA.EVOUTD, bit 3.
pub const EventOutputD = enum(u8) {
    /// Not connected to any pin.
    none = 0x0,
    /// PD7.
    alt1 = 0x1,
};

/// PORTMUX.CCLROUTEA.LUT0, bit 0.
pub const CclLut0 = enum(u8) {
    /// Inputs PA0..PA2, output PA3.
    default = 0x0,
    /// Inputs PA0..PA2, output PA6.
    alt1 = 0x1,
};

/// PORTMUX.CCLROUTEA.LUT1, bit 1.
pub const CclLut1 = enum(u8) {
    /// Inputs PC1, PC2; output PC3.
    default = 0x0,
    /// Inputs PC1, PC2; output not connected.
    alt1 = 0x1,
};

/// PORTMUX.CCLROUTEA.LUT2, bit 2.
pub const CclLut2 = enum(u8) {
    /// Not connected to any pin.
    default = 0x0,
    /// Output PD6.
    alt1 = 0x1,
};

fn write_field(address: u16, mask: u8, shift: u3, value: u8) void {
    const current = regs.read(address) & ~mask;
    regs.write(address, current | ((value << shift) & mask));
}

pub fn set_usart0(route: Usart0) void {
    write_field(regs.portmux.usartroutea, 0x07, 0, @intFromEnum(route));
}

pub fn set_usart1(route: Usart1) void {
    write_field(regs.portmux.usartroutea, 0x18, 3, @intFromEnum(route));
}

pub fn set_spi0(route: Spi0) void {
    write_field(regs.portmux.spiroutea, 0x07, 0, @intFromEnum(route));
}

pub fn set_twi0(route: Twi0) void {
    write_field(regs.portmux.twiroutea, 0x03, 0, @intFromEnum(route));
}

pub fn set_tca0(route: Tca0) void {
    write_field(regs.portmux.tcaroutea, 0x07, 0, @intFromEnum(route));
}

pub fn set_tcd0(route: Tcd0) void {
    write_field(regs.portmux.tcdroutea, 0x07, 0, @intFromEnum(route));
}

/// TCB0's waveform output can only go to PA2, so this is an on/off choice
/// rather than a position.
pub fn set_tcb0_output(enable: bool) void {
    if (enable) {
        regs.set_bits(regs.portmux.tcbroutea, regs.bit(0));
    } else {
        regs.clear_bits(regs.portmux.tcbroutea, regs.bit(0));
    }
}

/// TCB1's waveform output can only go to PA3.
pub fn set_tcb1_output(enable: bool) void {
    if (enable) {
        regs.set_bits(regs.portmux.tcbroutea, regs.bit(1));
    } else {
        regs.clear_bits(regs.portmux.tcbroutea, regs.bit(1));
    }
}

pub fn set_event_output_a(route: EventOutputA) void {
    write_field(regs.portmux.evsysroutea, 0x01, 0, @intFromEnum(route));
}

pub fn set_event_output_d(route: EventOutputD) void {
    write_field(regs.portmux.evsysroutea, 0x08, 3, @intFromEnum(route));
}

pub fn set_ccl_lut0(route: CclLut0) void {
    write_field(regs.portmux.cclroutea, 0x01, 0, @intFromEnum(route));
}

pub fn set_ccl_lut1(route: CclLut1) void {
    write_field(regs.portmux.cclroutea, 0x02, 1, @intFromEnum(route));
}

pub fn set_ccl_lut2(route: CclLut2) void {
    write_field(regs.portmux.cclroutea, 0x04, 2, @intFromEnum(route));
}
