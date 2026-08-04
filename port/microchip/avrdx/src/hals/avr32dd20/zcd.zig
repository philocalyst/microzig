//! ZCD3 - Zero-Cross Detector.
//!
//! DS40002413 section 35 "ZCD - Zero-Cross Detector", page 528.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=528
//!
//! The instance on this package is ZCD3, whose input is PC2. It senses the
//! zero crossing of an AC line fed through a current-limiting resistor, which
//! is what makes phase-angle control of a triac possible without an opto-
//! isolated detector.

const regs = @import("registers.zig");
const gpio = @import("gpio.zig");

/// ZCD3's sense pin.
pub const input_pin = gpio.pins.pc2;

/// ZCD.INTCTRL.INTMODE.
pub const InterruptMode = enum(u8) {
    none = 0x0,
    /// Rising edge of the detector output.
    rising = 0x1,
    falling = 0x2,
    both = 0x3,
};

pub const Config = struct {
    /// CTRLA.INVERT - invert the detector output.
    invert: bool = false,
    /// CTRLA.OUTEN - drive the detector output onto the pad.
    output_to_pin: bool = false,
    run_standby: bool = false,
    interrupt: InterruptMode = .none,
};

pub fn configure(config: Config) void {
    regs.write(regs.zcd3.ctrla, 0);

    gpio.set_direction(input_pin, .input);
    gpio.configure(input_pin, .{ .sense = .input_disable });

    regs.write(regs.zcd3.intctrl, @intFromEnum(config.interrupt));

    var ctrla: u8 = regs.bit(regs.zcd3.enable);
    if (config.invert) ctrla |= regs.bit(regs.zcd3.invert);
    if (config.output_to_pin) ctrla |= regs.bit(regs.zcd3.outen);
    if (config.run_standby) ctrla |= regs.bit(regs.zcd3.runstdby);
    regs.write(regs.zcd3.ctrla, ctrla);
}

pub fn disable() void {
    regs.write(regs.zcd3.ctrla, 0);
}

/// Current detector output.
pub fn state() bool {
    return (regs.read(regs.zcd3.status) & regs.bit(regs.zcd3.state)) != 0;
}

pub fn pending() bool {
    return (regs.read(regs.zcd3.status) & regs.bit(regs.zcd3.cross_if)) != 0;
}

pub fn clear_interrupt() void {
    regs.write(regs.zcd3.status, regs.bit(regs.zcd3.cross_if));
}
