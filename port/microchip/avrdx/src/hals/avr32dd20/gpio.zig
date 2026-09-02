//! PORT / VPORT - digital I/O.
//!
//! DS40002413 section 18 "PORT - I/O Pin Configuration", page 163.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=163
//!
//! The AVR32DD20 bonds out only 17 of the four ports' 32 possible pins, so
//! every pin-taking function requires the pin at comptime: PORTA is complete,
//! PORTC starts at PC1, PORTD at PD4, and PORTF exposes only PF6 and PF7.
//! Reaching for an unbonded pin is a compile error rather than a silent write
//! to a pad that does not exist, and PF6 -- input-only because it doubles as
//! RESET/UPDI -- cannot be made an output at all.
//!
//! Comptime pins also buy real atomicity: VPORT registers live in the low I/O
//! space, so a compile-time-known pin lowers to single-cycle SBI/CBI/SBIC
//! instead of a read-modify-write that an interrupt could tear. Passing a
//! runtime-computed pin is simply not expressible.
//! DS40002413 section 18.3.2.5 "Virtual Ports", page 167.

const std = @import("std");
const microzig = @import("microzig");
const capabilities = @import("capabilities.zig");

const chip = microzig.chip.peripherals;
const types = microzig.chip.types.peripherals;

/// Re-exported so callers can write `gpio.Port.a`.
pub const Port = capabilities.Port;
/// Pin data direction.
pub const Direction = enum { input, output };

/// VPORT block for a port in the low I/O space. For these first 0x20 bytes of
/// data space the I/O number equals the data address, which is what makes
/// SBI/CBI usable.
fn vport(comptime port: Port) *allowzero volatile types.VPORT {
    return switch (port) {
        .a => chip.VPORTA,
        .c => chip.VPORTC,
        .d => chip.VPORTD,
        .f => chip.VPORTF,
    };
}

fn port_block(comptime port: Port) *volatile types.PORT {
    return switch (port) {
        .a => chip.PORTA,
        .c => chip.PORTC,
        .d => chip.PORTD,
        .f => chip.PORTF,
    };
}

/// The shared shape of every PINnCTRL / PINCONFIG register, taken from the
/// generated layer rather than re-declared here.
const PinCtrlBits = @FieldType(types.PORT, "PIN0CTRL").underlying_type;
const PinConfigBits = @FieldType(types.PORT, "PINCONFIG").underlying_type;

/// How many pins a port really has on this package.
pub fn available_pins(comptime port: Port) u8 {
    return port.available_pins();
}

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

    pub fn encode(config: PinConfig) PinCtrlBits {
        return .{
            .ISC = @fromBackingInt(@intCast(@backingInt(config.sense))),
            .PULLUPEN = @intFromBool(config.pullup),
            .INLVL = @intFromBool(config.ttl_input),
            .INVEN = @intFromBool(config.invert),
        };
    }

    fn decode(bits: PinCtrlBits) PinConfig {
        return .{
            .sense = @fromBackingInt(@intCast(@backingInt(bits.ISC))),
            .pullup = bits.PULLUPEN != 0,
            .ttl_input = bits.INLVL != 0,
            .invert = bits.INVEN != 0,
        };
    }
};

/// Compile-time pin handle: port plus index, checked against the
/// bonded-pin map at construction.
pub const Pin = packed struct(u5) {
    index: u3,
    port: Port,

    /// Construct a pin, rejecting pads the 20-pin package does not bond.
    pub fn init(comptime port: Port, comptime index: u3) Pin {
        comptime {
            if (!port.bonded(index)) {
                @compileError(std.fmt.comptimePrint(
                    "P{c}{d} is not bonded out on the AVR32DD20 (20-pin package)",
                    .{ std.ascii.toUpper(@tagName(port)[0]), index },
                ));
            }
        }
        return .{ .port = port, .index = index };
    }

    pub inline fn mask(p: Pin) u8 {
        return @as(u8, 1) << p.index;
    }

    pub inline fn set_direction(p: Pin, comptime direction: Direction) void {
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
};

const gpio = @This();

/// Build a pin handle; non-bonded pads are compile errors.
pub fn pin(comptime port: Port, comptime index: u3) Pin {
    return Pin.init(port, index);
}

// -- Single-pin access -------------------------------------------------------
//
// Pins are comptime values so all address arithmetic folds away and low-I/O
// accesses become SBI/CBI/SBIC.

/// Set direction with one SBI/CBI -- atomic, no read-modify-write.
pub fn set_direction(comptime p: Pin, comptime direction: Direction) void {
    switch (direction) {
        .input => microzig.cpu.cbi(io_num_vport_dir(p.port), p.index),
        .output => {
            comptime if (!p.port.output_capable(p.index))
                @compileError("pin cannot drive: input-only on this package");
            microzig.cpu.sbi(io_num_vport_dir(p.port), p.index);
        },
    }
}

/// Sample the pad level through VPORTx.IN.
pub fn read(comptime p: Pin) bool {
    return (vport(p.port).IN & p.mask()) != 0;
}

/// Drive a value through PORT OUTSET/OUTCLR: one store either way,
/// safe against interrupts touching other pins of the port.
pub fn put(comptime p: Pin, value: bool) void {
    // The VPORT block has no set/clear aliases, but the full PORT block's
    // OUTSET/OUTCLR are single stores too -- same atomicity, no RMW.
    const pb = port_block(p.port);
    if (value) {
        pb.OUTSET = p.mask();
    } else {
        pb.OUTCLR = p.mask();
    }
}

/// Flip the output through VPORTx.INVT -- one store.
pub fn toggle(comptime p: Pin) void {
    // PORTn.OUTTGL flips in one write with no read-modify-write; the VPORT has
    // no toggle alias, so this goes through the full PORT block.
    port_block(p.port).OUTTGL = p.mask();
}

/// Apply a full PINnCTRL configuration to one pin.
///
/// DS40002413 section 18.3.2.3 "Pin Configuration", page 165.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=165
pub fn configure(comptime p: Pin, config: PinConfig) void {
    const value = config.encode();
    write_pinctrl(p, @bitCast(value));
}

/// Read back a pin's current configuration.
pub fn configured(comptime p: Pin) PinConfig {
    const pb = port_block(p.port);
    const bits: PinCtrlBits = @bitCast(switch (p.index) {
        0 => pb.PIN0CTRL.raw,
        1 => pb.PIN1CTRL.raw,
        2 => pb.PIN2CTRL.raw,
        3 => pb.PIN3CTRL.raw,
        4 => pb.PIN4CTRL.raw,
        5 => pb.PIN5CTRL.raw,
        6 => pb.PIN6CTRL.raw,
        7 => pb.PIN7CTRL.raw,
    });
    return PinConfig.decode(bits);
}

/// Configure a pin as an input in one call.
pub fn configure_input(comptime p: Pin, config: PinConfig) void {
    set_direction(p, .input);
    configure(p, config);
}

/// Configure a pin as an output and give it an initial level. Compile error
/// for input-only pins such as PF6.
pub fn configure_output(comptime p: Pin, initial: bool) void {
    comptime if (!p.port.output_capable(p.index))
        @compileError("pin cannot be configured as output");
    put(p, initial);
    set_direction(p, .output);
}

/// Runtime variant of `port_block` for the `_rt` helpers.
fn port_block_rt(port: Port) *volatile types.PORT {
    return switch (port) {
        .a => chip.PORTA,
        .c => chip.PORTC,
        .d => chip.PORTD,
        .f => chip.PORTF,
    };
}

fn io_num_vport_dir(comptime port: Port) u5 {
    // DIR is the first register of the VPORT block; the low I/O numbers are
    // identity-mapped with their data addresses.
    comptime return @intCast(@intFromPtr(vport(port)));
}

fn write_pinctrl(comptime p: Pin, value: u8) void {
    const pb = port_block(p.port);
    switch (p.index) {
        0 => pb.PIN0CTRL.write_raw(value),
        1 => pb.PIN1CTRL.write_raw(value),
        2 => pb.PIN2CTRL.write_raw(value),
        3 => pb.PIN3CTRL.write_raw(value),
        4 => pb.PIN4CTRL.write_raw(value),
        5 => pb.PIN5CTRL.write_raw(value),
        6 => pb.PIN6CTRL.write_raw(value),
        7 => pb.PIN7CTRL.write_raw(value),
    }
}

// -- Runtime-pin variants ----------------------------------------------------
//
// The comptime requirement above exists to guarantee SBI/CBI atomicity. When
// a pin only becomes known at run time, these plain-store equivalents are
// safe as long as no ISR touches the same port's DIR/PINCTRL registers.

/// Direction change for a run-time-known pin using DIRSET/DIRCLR.
/// Plain stores, but no SBI/CBI atomicity guarantee.
pub fn set_direction_rt(p: Pin, direction: Direction) void {
    const pb = port_block_rt(p.port);
    switch (direction) {
        .input => pb.DIRCLR = p.mask(),
        .output => pb.DIRSET = p.mask(),
    }
}

/// Write PINnCTRL for a run-time-known pin. A plain store is safe as
/// long as no ISR configures another pin of the same port concurrently.
pub fn configure_rt(p: Pin, config: PinConfig) void {
    const pb = port_block_rt(p.port);
    const value: u8 = @bitCast(config.encode());
    switch (p.index) {
        0 => pb.PIN0CTRL.write_raw(value),
        1 => pb.PIN1CTRL.write_raw(value),
        2 => pb.PIN2CTRL.write_raw(value),
        3 => pb.PIN3CTRL.write_raw(value),
        4 => pb.PIN4CTRL.write_raw(value),
        5 => pb.PIN5CTRL.write_raw(value),
        6 => pb.PIN6CTRL.write_raw(value),
        7 => pb.PIN7CTRL.write_raw(value),
    }
}

// -- Whole-port access -------------------------------------------------------

/// Read every input on a port at once. Bits for unbonded pads read as 0.
pub fn read_port(comptime port: Port) u8 {
    return vport(port).IN & port.available_pins();
}

/// Drive a whole port. `mask` selects which pins are written, which keeps this
/// from disturbing pins owned by a peripheral.
pub fn write_port(comptime port: Port, mask: u8, value: u8) void {
    const bits = mask & port.available_pins();
    const pb = port_block(port);
    pb.OUTSET = bits & value;
    pb.OUTCLR = bits & ~value;
}

/// Change direction of several pins at once. `mask` limits the update
/// to the listed pins; unbonded bits are ignored.
pub fn set_port_direction(comptime port: Port, mask: u8, direction: Direction) void {
    const bits = mask & port.available_pins();
    const pb = port_block(port);
    switch (direction) {
        .input => pb.DIRCLR = bits,
        .output => pb.DIRSET = bits,
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

/// Apply one PINCONFIG byte to several pins of a port at once via the
/// PINCTRLUPD command -- a single store instead of one per pin.
pub fn configure_pins(comptime port: Port, mask: u8, config: PinConfig, mode: MultiPinMode) void {
    const pb = port_block(port);
    pb.PINCONFIG.write(.{
        .ISC = @fromBackingInt(@intCast(@backingInt(config.sense))),
        .PULLUPEN = @intFromBool(config.pullup),
        .INLVL = @intFromBool(config.ttl_input),
        .INVEN = @intFromBool(config.invert),
    });
    const masked = mask & port.available_pins();
    switch (mode) {
        .overwrite => pb.PINCTRLUPD.write_raw(masked),
        .set => pb.PINCTRLSET.write_raw(masked),
        .clear => pb.PINCTRLCLR.write_raw(masked),
    }
}

/// Disable the input buffer on every bonded-but-unused pad of every port.
///
/// A floating input buffer burns current; the datasheet's recommendation for
/// unused pins is `input_disable` (or a pull-up). Pass a mask of pins your
/// board actually uses per port; everything bonded-but-unlisted gets its
/// buffer shut off. Worth calling once at start-up on a battery-powered board.
pub fn disable_unused_inputs(comptime used: struct { a: u8 = 0, c: u8 = 0, d: u8 = 0, f: u8 = 0 }) void {
    inline for (comptime std.enums.values(Port)) |port| {
        const used_mask = @field(used, @tagName(port));
        const unused = port.available_pins() & ~used_mask;
        if (unused != 0) {
            configure_pins(port, unused, .{ .sense = .input_disable }, .overwrite);
        }
    }
}

/// Limit the slew rate of every output on a port (PORTn.PORTCTRL.SRL).
pub fn set_slew_rate_limit(comptime port: Port, enable: bool) void {
    port_block(port).PORTCTRL.modify(.{ .SRL = @intFromBool(enable) });
}

// -- Pin interrupts ----------------------------------------------------------

/// Enable a pin-change interrupt by giving the pin a sense mode.
///
/// Each port has one interrupt vector shared by its eight pins; read
/// `interrupt_flags` in the handler to find out which pin fired.
pub fn enable_interrupt(comptime p: Pin, sense: Sense, pullup: bool) void {
    configure_input(p, .{ .sense = sense, .pullup = pullup });
}

/// Clear both interrupt senses for a pin, masking it without touching
/// other pins' configuration.
pub fn disable_interrupt(comptime p: Pin) void {
    var cfg = configured(p);
    cfg.sense = .interrupt_disabled;
    configure(p, cfg);
}

/// Pending pin interrupts for a port, as a bit mask.
pub fn interrupt_flags(comptime port: Port) u8 {
    return vport(port).INTFLAGS;
}

/// Flags are cleared by writing a one to them.
pub fn clear_interrupt(comptime p: Pin) void {
    vport(p.port).INTFLAGS = p.mask();
}

/// Clear the latched flags of the listed pins in one INTFLAGS store.
pub fn clear_interrupts(comptime port: Port, mask: u8) void {
    vport(port).INTFLAGS = mask;
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

    /// Shared with RESET (RSTPINCFG); input-only either way.
    pub const pf6 = pin(.f, 6);
    /// The UPDI programming pin; usable as GPIO only if UPDI is disabled.
    pub const pf7 = pin(.f, 7);
};
