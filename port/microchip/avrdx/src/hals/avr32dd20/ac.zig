//! AC0 - Analog Comparator.
//!
//! DS40002413 section 32 "AC - Analog Comparator", page 482.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=482
//!
//! Only a subset of the comparator's mux inputs is bonded out on the 20-pin
//! package, so the enums below list exactly what this part can reach. The
//! encodings themselves are re-exported from the generated layer.

const microzig = @import("microzig");
const gpio = @import("gpio.zig");

const ac = microzig.chip.peripherals.AC0;
const gen = microzig.chip.types.peripherals.AC;

/// AC0.MUXCTRL.MUXPOS. AINP0 has no pad on the 20-pin package.
pub const PositiveInput = enum(u3) {
    /// PD6.
    ainp3_pd6 = 0x3,
    /// PC3.
    ainp4_pc3 = 0x4,

    fn to_field(input: PositiveInput) gen.AC_MUXPOS {
        return @fromBackingInt(@intCast(@backingInt(input)));
    }
};

/// AC0.MUXCTRL.MUXNEG. AINN0 and AINN1 have no pad on the 20-pin package.
pub const NegativeInput = enum(u3) {
    /// PD7.
    ainn2_pd7 = 0x2,
    /// PC2.
    ainn3_pc2 = 0x3,
    /// The internal DACREF, an 8-bit level derived from `VREF.ACREF`. Lets the
    /// comparator work as a programmable threshold detector with no external
    /// divider.
    dacref = 0x4,

    fn to_field(input: NegativeInput) gen.AC_MUXNEG {
        return @fromBackingInt(@intCast(@backingInt(input)));
    }

    pub fn pin(input: NegativeInput) ?gpio.Pin {
        return switch (input) {
            .ainn2_pd7 => gpio.pins.pd7,
            .ainn3_pc2 => gpio.pins.pc2,
            .dacref => null,
        };
    }
};

/// Positive input pad, for boards that switch inputs at run time.
pub fn positive_pin(input: PositiveInput) gpio.Pin {
    return switch (input) {
        .ainp3_pd6 => gpio.pins.pd6,
        .ainp4_pc3 => gpio.pins.pc3,
    };
}

/// AC0.CTRLA.HYSMODE - input hysteresis, which stops a slow-moving input from
/// chattering the output.
pub const Hysteresis = gen.AC_HYSMODE;

/// AC0.CTRLA.POWER - trades response time against current.
pub const PowerProfile = gen.AC_POWER;

/// AC0.INTCTRL.INTMODE - which output transition raises the interrupt.
pub const InterruptMode = gen.AC_NORMAL_INTMODE;

const CtrlABits = @TypeOf(ac.CTRLA.read());
const MuxctrlBits = @TypeOf(ac.MUXCTRL.read());

/// Comparator setup: input muxing, hysteresis, power profile and
/// optional pin output.
pub const Config = struct {
    positive: PositiveInput = .ainp3_pd6,
    negative: NegativeInput = .dacref,
    hysteresis: Hysteresis = .NONE,
    power: PowerProfile = .PROFILE0,
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

/// Configure and enable AC0.
///
/// Writes the mux, control and interrupt registers with the
/// comparator disabled first, then enables it. When
/// `configure_pins` is set the digital input buffers on both
/// selected pads are switched off, which analog sources need.
///
/// DS40002413 section 32.3.1 "Initialization", page 483.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=483
pub fn configure(comptime config: Config) void {
    ac.CTRLA.write(.{
        .ENABLE = 0,
        .HYSMODE = .NONE,
        .POWER = .PROFILE0,
        .OUTEN = 0,
        .RUNSTDBY = 0,
    });

    if (config.configure_pins) {
        disable_digital_input(positive_pin(config.positive));
        if (config.negative.pin()) |p| disable_digital_input(p);
    }

    if (config.negative == .dacref) {
        ac.DACREF.write(.{ .DACREF = config.dacref });
    }

    ac.MUXCTRL.write(.{
        .MUXNEG = config.negative.to_field(),
        .MUXPOS = config.positive.to_field(),
        .INITVAL = .LOW,
        .INVERT = @intFromBool(config.invert),
    });

    ac.CTRLA.write(.{
        .ENABLE = 1,
        .HYSMODE = config.hysteresis,
        .POWER = config.power,
        .OUTEN = @intFromBool(config.output_to_pin),
        .RUNSTDBY = @intFromBool(config.run_standby),
    });
}

fn disable_digital_input(comptime p: gpio.Pin) void {
    gpio.set_direction(p, .input);
    gpio.configure(p, .{ .sense = .input_disable });
}

/// Disable the comparator (CTRLA.ENABLE = 0).
pub fn disable() void {
    ac.CTRLA.write(.{
        .ENABLE = 0,
        .HYSMODE = .NONE,
        .POWER = .PROFILE0,
        .OUTEN = 0,
        .RUNSTDBY = 0,
    });
}

/// Change the DACREF threshold at run time.
pub fn set_dacref(value: u8) void {
    ac.DACREF.write(.{ .DACREF = value });
}

/// Current comparator output: true when the positive input is above the
/// negative one.
pub fn state() bool {
    return ac.STATUS.read().CMPSTATE != 0;
}

/// Raise the AC interrupt on the given output transition.
pub fn enable_interrupt(mode: InterruptMode) void {
    ac.INTCTRL.write(.{
        .CMP = 1,
        .INTMODE = mode,
    });
}

/// Mask the AC interrupt without touching the flag.
pub fn disable_interrupt() void {
    ac.INTCTRL.write(.{
        .CMP = 0,
        .INTMODE = .BOTHEDGE,
    });
}

/// True when the selected crossing happened since the last clear.
pub fn pending() bool {
    return ac.STATUS.read().CMPIF != 0;
}

/// Clear the crossing flag (write-one-to-clear).
pub fn clear_interrupt() void {
    // STATUS mixes the W1C flag with the read-only CMPSTATE bit, so clears
    // go through read-modify-write instead of a full literal.
    var status = ac.STATUS.read();
    status.CMPIF = 1;
    ac.STATUS.write(status);
}
