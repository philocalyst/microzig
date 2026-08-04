//! AC0 - Analog Comparator.
//!
//! DS40002413 section 32 "AC - Analog Comparator", page 482.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=482
//!
//! Only a subset of the comparator's mux inputs is bonded out on the 20-pin
//! package, so the enums below list exactly what this part can reach.

const regs = @import("registers.zig");
const gpio = @import("gpio.zig");

/// AC0.MUXCTRL.MUXPOS. AINP0 has no pad on the 20-pin package.
pub const PositiveInput = enum(u8) {
    /// PD6.
    ainp3_pd6 = 0x3,
    /// PC3.
    ainp4_pc3 = 0x4,

    pub fn pin(input: PositiveInput) gpio.Pin {
        return switch (input) {
            .ainp3_pd6 => gpio.pins.pd6,
            .ainp4_pc3 => gpio.pins.pc3,
        };
    }
};

/// AC0.MUXCTRL.MUXNEG. AINN0 and AINN1 have no pad on the 20-pin package.
pub const NegativeInput = enum(u8) {
    /// PD7.
    ainn2_pd7 = 0x2,
    /// PC2.
    ainn3_pc2 = 0x3,
    /// The internal DACREF, an 8-bit level derived from `VREF.ACREF`. Lets the
    /// comparator work as a programmable threshold detector with no external
    /// divider.
    dacref = 0x4,

    pub fn pin(input: NegativeInput) ?gpio.Pin {
        return switch (input) {
            .ainn2_pd7 => gpio.pins.pd7,
            .ainn3_pc2 => gpio.pins.pc2,
            .dacref => null,
        };
    }
};

/// AC0.CTRLA.HYSMODE - input hysteresis, which stops a slow-moving input from
/// chattering the output.
pub const Hysteresis = enum(u8) {
    none = 0x0,
    mv10 = 0x1,
    mv25 = 0x2,
    mv50 = 0x3,
};

/// AC0.CTRLA.POWER - trades response time against current.
pub const PowerProfile = enum(u8) {
    /// Fastest response, highest current.
    profile0 = 0x0,
    profile1 = 0x1,
    profile2 = 0x2,
    profile3 = 0x3,
};

/// AC0.INTCTRL.INTMODE - which output transition raises the interrupt.
pub const InterruptMode = enum(u8) {
    both_edges = 0x0,
    negative_edge = 0x2,
    positive_edge = 0x3,
};

pub const Config = struct {
    positive: PositiveInput = .ainp3_pd6,
    negative: NegativeInput = .dacref,
    hysteresis: Hysteresis = .none,
    power: PowerProfile = .profile0,
    /// CTRLA.OUTEN - drive the comparator result onto PA7.
    output_to_pin: bool = false,
    /// MUXCTRL.INVERT - invert the comparator output.
    invert: bool = false,
    run_standby: bool = false,
    /// DACREF level, used when `negative` is `.dacref`. The threshold is
    /// `VREF.ACREF * dacref / 256`.
    dacref: u8 = 128,
    /// Disable the digital input buffers on the pins in use, as an analog
    /// input requires.
    configure_pins: bool = true,
};

pub fn configure(config: Config) void {
    regs.write(regs.ac0.ctrla, 0);

    if (config.configure_pins) {
        disable_digital_input(config.positive.pin());
        if (config.negative.pin()) |p| disable_digital_input(p);
    }

    if (config.negative == .dacref) {
        regs.write(regs.ac0.dacref, config.dacref);
    }

    var muxctrl: u8 = @intFromEnum(config.negative) |
        (@as(u8, @intFromEnum(config.positive)) << 3);
    if (config.invert) muxctrl |= regs.bit(regs.ac0.invert);
    regs.write(regs.ac0.muxctrl, muxctrl);

    var ctrla: u8 = regs.bit(regs.ac0.enable) |
        (@as(u8, @intFromEnum(config.hysteresis)) << 1) |
        (@as(u8, @intFromEnum(config.power)) << 3);
    if (config.output_to_pin) ctrla |= regs.bit(regs.ac0.outen);
    if (config.run_standby) ctrla |= regs.bit(regs.ac0.runstdby);
    regs.write(regs.ac0.ctrla, ctrla);
}

fn disable_digital_input(p: gpio.Pin) void {
    gpio.set_direction(p, .input);
    gpio.configure(p, .{ .sense = .input_disable });
}

pub fn disable() void {
    regs.write(regs.ac0.ctrla, 0);
}

/// Change the DACREF threshold at run time.
pub fn set_dacref(value: u8) void {
    regs.write(regs.ac0.dacref, value);
}

/// Current comparator output: true when the positive input is above the
/// negative one.
pub fn state() bool {
    return (regs.read(regs.ac0.status) & regs.bit(regs.ac0.state)) != 0;
}

pub fn enable_interrupt(mode: InterruptMode) void {
    regs.write(
        regs.ac0.intctrl,
        regs.bit(regs.ac0.cmp) | (@as(u8, @intFromEnum(mode)) << 4),
    );
}

pub fn disable_interrupt() void {
    regs.write(regs.ac0.intctrl, 0);
}

pub fn pending() bool {
    return (regs.read(regs.ac0.status) & regs.bit(regs.ac0.cmp)) != 0;
}

pub fn clear_interrupt() void {
    regs.write(regs.ac0.status, regs.bit(regs.ac0.cmp));
}
