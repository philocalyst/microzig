//! PORT / VPORT - digital I/O.
//!
//! DS40002413 section 18 "PORT - I/O Pin Configuration", page 163.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=163
//!
//! The AVR32DD20 bonds out only 17 of the four ports' 32 possible pins, so
//! `Pin.init` is comptime-checked against the package: PORTA is complete,
//! PORTC starts at PC1, PORTD at PD4, and PORTF exposes only PF6 and PF7.
//! Reaching for an unbonded pin is a compile error rather than a silent write
//! to a pad that does not exist.

const std = @import("std");
const regs = @import("registers.zig");

const gpio = @This();

pub const Port = enum(u2) {
    a,
    c,
    d,
    f,

    /// Mask of pins that are actually bonded out on the 20-pin package, from
    /// the ATDF DIP20MVIO/QFP20MVIO pinouts.
    pub fn available_pins(port: Port) u8 {
        return switch (port) {
            .a => 0b1111_1111, // PA0..PA7
            .c => 0b0000_1110, // PC1..PC3
            .d => 0b1111_0000, // PD4..PD7
            .f => 0b1100_0000, // PF6, PF7
        };
    }

    pub fn base(port: Port) u16 {
        return switch (port) {
            .a => regs.porta_base,
            .c => regs.portc_base,
            .d => regs.portd_base,
            .f => regs.portf_base,
        };
    }

    /// Base of the port's virtual-port alias in the low I/O space.
    pub fn vbase(port: Port) u16 {
        return switch (port) {
            .a => regs.vporta.base,
            .c => regs.vportc.base,
            .d => regs.vportd.base,
            .f => regs.vportf.base,
        };
    }
};

pub const Direction = enum { input, output };

/// PORTn.PINnCTRL.ISC - what the pin's input buffer does and when it raises an
/// interrupt. DS40002413 section 18.3.3 "Interrupts", page 167.
pub const Sense = enum(u3) {
    /// Input buffer enabled, no interrupt.
    interrupt_disabled = 0x0,
    both_edges = 0x1,
    rising = 0x2,
    falling = 0x3,
    /// Input buffer disabled entirely - the lowest-power state for an unused
    /// pin, and required for a pin used as an analog input.
    input_disable = 0x4,
    /// Level-sensitive low. Only this and `both_edges` can wake the part from
    /// power-down on a fully asynchronous pin.
    level = 0x5,
};

/// Everything PINnCTRL controls for one pin.
pub const PinConfig = struct {
    sense: Sense = .interrupt_disabled,
    pullup: bool = false,
    /// INLVL: use TTL thresholds instead of Schmitt-trigger. Only meaningful
    /// on the MVIO port (PORTC) -- DS40002413 section 19 "MVIO", page 192.
    ttl_input: bool = false,
    /// INVEN: invert both the input and the output of the pin.
    invert: bool = false,

    pub fn encode(config: PinConfig) u8 {
        var value: u8 = @intFromEnum(config.sense);
        if (config.pullup) value |= regs.bit(regs.port_bits.pullupen);
        if (config.ttl_input) value |= regs.bit(regs.port_bits.inlvl);
        if (config.invert) value |= regs.bit(regs.port_bits.inven);
        return value;
    }
};

pub const Pin = packed struct(u5) {
    index: u3,
    port: Port,

    /// Construct a pin, rejecting pads that the 20-pin package does not bond.
    pub fn init(comptime port: Port, comptime index: u3) Pin {
        comptime {
            if ((port.available_pins() & (@as(u8, 1) << index)) == 0) {
                @compileError(std.fmt.comptimePrint(
                    "P{c}{d} is not bonded out on the AVR32DD20 (20-pin package)",
                    .{ std.ascii.toUpper(@tagName(port)[0]), index },
                ));
            }
        }
        return .{ .port = port, .index = index };
    }

    pub inline fn mask(p: Pin) u8 {
        return regs.bit(p.index);
    }

    pub inline fn set_direction(p: Pin, direction: Direction) void {
        gpio.set_direction(p, direction);
    }

    pub inline fn read(p: Pin) bool {
        return gpio.read(p);
    }

    pub inline fn put(p: Pin, value: bool) void {
        gpio.put(p, value);
    }

    pub inline fn toggle(p: Pin) void {
        gpio.toggle(p);
    }

    pub inline fn configure(p: Pin, config: PinConfig) void {
        gpio.configure(p, config);
    }

    /// Address of this pin's PINnCTRL register.
    pub inline fn pinctrl(p: Pin) u16 {
        return p.port.base() + regs.port_offsets.pin0ctrl + @as(u16, p.index);
    }
};

pub fn pin(comptime port: Port, comptime index: u3) Pin {
    return Pin.init(port, index);
}

// -- Single-pin access -------------------------------------------------------
//
// Direction, output and input all go through the VPORT alias. VPORT registers
// sit in the low I/O space, so a compile-time-known pin lowers to the atomic
// single-cycle SBI/CBI/SBIC instructions instead of a read-modify-write that
// an interrupt could tear.
// DS40002413 section 18.3.2.5 "Virtual Ports", page 167.

pub fn set_direction(p: Pin, direction: Direction) void {
    const dir = p.port.vbase() + 0x0;
    switch (direction) {
        .input => regs.clear_bits(dir, p.mask()),
        .output => regs.set_bits(dir, p.mask()),
    }
}

pub fn read(p: Pin) bool {
    return (regs.read(p.port.vbase() + 0x2) & p.mask()) != 0;
}

pub fn put(p: Pin, value: bool) void {
    const out = p.port.vbase() + 0x1;
    if (value) {
        regs.set_bits(out, p.mask());
    } else {
        regs.clear_bits(out, p.mask());
    }
}

pub fn toggle(p: Pin) void {
    // PORTn.OUTTGL flips in one write with no read-modify-write; VPORT has no
    // toggle alias, so this one goes through the full PORT block.
    regs.write(p.port.base() + regs.port_offsets.outtgl, p.mask());
}

/// Apply a full PINnCTRL configuration to one pin.
///
/// DS40002413 section 18.3.2.3 "Pin Configuration", page 165.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=165
pub fn configure(p: Pin, config: PinConfig) void {
    regs.write(p.pinctrl(), config.encode());
}

/// Configure a pin as an input in one call.
pub fn configure_input(p: Pin, config: PinConfig) void {
    set_direction(p, .input);
    configure(p, config);
}

/// Configure a pin as an output and give it an initial level.
pub fn configure_output(p: Pin, initial: bool) void {
    put(p, initial);
    set_direction(p, .output);
}

// -- Whole-port access -------------------------------------------------------

/// Read every input on a port at once. Bits for unbonded pads read as 0.
pub fn read_port(port: Port) u8 {
    return regs.read(port.vbase() + 0x2) & port.available_pins();
}

/// Drive a whole port. `mask` selects which pins are written, which keeps this
/// from disturbing pins owned by a peripheral.
pub fn write_port(port: Port, mask: u8, value: u8) void {
    const bits = mask & port.available_pins();
    regs.write(port.base() + regs.port_offsets.outset, bits & value);
    regs.write(port.base() + regs.port_offsets.outclr, bits & ~value);
}

pub fn set_port_direction(port: Port, mask: u8, direction: Direction) void {
    const bits = mask & port.available_pins();
    switch (direction) {
        .input => regs.write(port.base() + regs.port_offsets.dirclr, bits),
        .output => regs.write(port.base() + regs.port_offsets.dirset, bits),
    }
}

/// Apply one PINnCTRL configuration to several pins of a port in a single
/// operation.
///
/// DS40002413 section 18.3.2.4 "Multi-Pin Configuration", page 166: write the
/// desired configuration to PORTn.PINCONFIG, then write a pin mask to
/// PINCTRLUPD (overwrite), PINCTRLSET (OR in) or PINCTRLCLR (AND out). This is
/// new on AVR Dx and replaces a loop over eight PINnCTRL registers.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=166
pub const MultiPinMode = enum { overwrite, set, clear };

pub fn configure_pins(port: Port, mask: u8, config: PinConfig, mode: MultiPinMode) void {
    const base = port.base();
    regs.write(base + regs.port_offsets.pinconfig, config.encode());
    const target = switch (mode) {
        .overwrite => base + regs.port_offsets.pinctrlupd,
        .set => base + regs.port_offsets.pinctrlset,
        .clear => base + regs.port_offsets.pinctrlclr,
    };
    regs.write(target, mask & port.available_pins());
}

/// Disable the input buffer on every pad the package does not bond out.
///
/// A floating input buffer burns current; the datasheet's recommendation for
/// unused pins is `input_disable` (or a pull-up). Worth calling once at start-up
/// on a battery-powered board.
pub fn disable_unbonded_inputs() void {
    inline for (comptime std.enums.values(Port)) |port| {
        const unbonded = ~port.available_pins();
        if (unbonded != 0) {
            configure_pins(port, unbonded, .{ .sense = .input_disable }, .overwrite);
        }
    }
}

/// Limit the slew rate of every output on a port (PORTn.PORTCTRL.SRL).
pub fn set_slew_rate_limit(port: Port, enable: bool) void {
    const address = port.base() + regs.port_offsets.portctrl;
    if (enable) {
        regs.set_bits(address, regs.bit(regs.port_bits.srl));
    } else {
        regs.clear_bits(address, regs.bit(regs.port_bits.srl));
    }
}

// -- Pin interrupts ----------------------------------------------------------

/// Enable a pin-change interrupt by giving the pin a sense mode.
///
/// Each port has one interrupt vector shared by its eight pins; read
/// `interrupt_flags` in the handler to find out which pin fired.
pub fn enable_interrupt(p: Pin, sense: Sense, pullup: bool) void {
    configure_input(p, .{ .sense = sense, .pullup = pullup });
}

pub fn disable_interrupt(p: Pin) void {
    regs.clear_bits(p.pinctrl(), 0x07);
}

/// Pending pin interrupts for a port, as a bit mask.
pub fn interrupt_flags(port: Port) u8 {
    return regs.read(port.vbase() + 0x3);
}

/// Flags are cleared by writing a one to them.
pub fn clear_interrupt(p: Pin) void {
    regs.write(p.port.vbase() + 0x3, p.mask());
}

pub fn clear_interrupts(port: Port, mask: u8) void {
    regs.write(port.vbase() + 0x3, mask);
}

// -- Named pins --------------------------------------------------------------

/// The 17 pads the 20-pin package actually bonds, from the ATDF pinout.
pub const pins = struct {
    pub const pa0 = pin(.a, 0);
    pub const pa1 = pin(.a, 1);
    pub const pa2 = pin(.a, 2);
    pub const pa3 = pin(.a, 3);
    pub const pa4 = pin(.a, 4);
    pub const pa5 = pin(.a, 5);
    pub const pa6 = pin(.a, 6);
    pub const pa7 = pin(.a, 7);

    /// PORTC is powered from VDDIO2, not VDD. See `mvio`.
    pub const pc1 = pin(.c, 1);
    pub const pc2 = pin(.c, 2);
    pub const pc3 = pin(.c, 3);

    pub const pd4 = pin(.d, 4);
    pub const pd5 = pin(.d, 5);
    pub const pd6 = pin(.d, 6);
    pub const pd7 = pin(.d, 7);

    /// Shared with RESET, depending on FUSE.SYSCFG0.RSTPINCFG.
    pub const pf6 = pin(.f, 6);
    /// The UPDI programming pin; usable as GPIO only if UPDI is disabled.
    pub const pf7 = pin(.f, 7);
};
