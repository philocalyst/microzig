//! ZCD3 - Zero-Cross Detector.
//!
//! DS40002413 section 35 "ZCD - Zero-Cross Detector", page 528.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=528
//!
//! The instance on this package is ZCD3, whose input is PC2. It senses the
//! zero crossing of an AC line fed through a current-limiting resistor, which
//! is what makes phase-angle control of a triac possible without an opto-
//! isolated detector.

const microzig = @import("microzig");
const gpio = @import("gpio.zig");

const zcd = microzig.chip.peripherals.ZCD3;
const gen = microzig.chip.types.peripherals.ZCD;

/// ZCD3's sense pin.
pub const input_pin = gpio.pins.pc2;

/// ZCD.INTCTRL.INTMODE; encodings re-exported from the generated layer.
pub const InterruptMode = gen.ZCD_INTMODE;

/// Zero-cross detector configuration.
pub const Config = struct {
    /// CTRLA.INVERT - invert the detector output.
    invert: bool = false,
    /// CTRLA.OUTEN - drive the detector output onto the pad.
    output_to_pin: bool = false,
    run_standby: bool = false,
    interrupt: InterruptMode = .NONE,

    fn to_bits(config: Config) CtrlABits {
        return .{
            .ENABLE = 1,
            .INVERT = @intFromBool(config.invert),
            .OUTEN = @intFromBool(config.output_to_pin),
            .RUNSTDBY = @intFromBool(config.run_standby),
        };
    }
};

const CtrlABits = @TypeOf(zcd.CTRLA.read());

/// Apply the configuration and enable ZCD3.
///
/// DS40002413 section 35.3.1 "Initialization", page 529.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=529
pub fn configure(config: Config) void {
    zcd.CTRLA.write(.{
        .ENABLE = 0,
        .INVERT = @intFromBool(config.invert),
        .OUTEN = @intFromBool(config.output_to_pin),
        .RUNSTDBY = @intFromBool(config.run_standby),
    });

    gpio.set_direction(input_pin, .input);
    gpio.configure(input_pin, .{ .sense = .input_disable });

    zcd.INTCTRL.write(.{ .INTMODE = config.interrupt });
    zcd.CTRLA.write(config.to_bits());
}

/// Disable ZCD3.
pub fn disable() void {
    zcd.CTRLA.write(.{
        .ENABLE = 0,
        .INVERT = 0,
        .OUTEN = 0,
        .RUNSTDBY = 0,
    });
}

/// Current detector output.
pub fn state() bool {
    return zcd.STATUS.read().STATE == .HIGH;
}

/// True since the last clear when ACx crossed zero.
pub fn pending() bool {
    return zcd.STATUS.read().CROSSIF != 0;
}

/// Clear the crossing flag.
pub fn clear_interrupt() void {
    var status = zcd.STATUS.read();
    status.CROSSIF = 1;
    zcd.STATUS.write(status);
}
