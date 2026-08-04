//! DAC0 - 10-bit Digital-to-Analog Converter.
//!
//! DS40002413 section 34 "DAC - Digital-to-Analog Converter", page 522.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=522
//!
//! The output buffer drives PD6 on this package. The DAC can also be used
//! purely internally as a reference for the analog comparator or a source for
//! the ADC, in which case leave `output_to_pin` off.

const regs = @import("registers.zig");
const gpio = @import("gpio.zig");
const vref = @import("vref.zig");

/// The output pad, when `Config.output_to_pin` is set.
pub const output_pin = gpio.pins.pd6;

pub const resolution_bits = 10;
pub const max_value: u10 = 1023;

pub const Config = struct {
    reference: vref.Reference = .internal_2v048,
    /// CTRLA.OUTEN - drive PD6. Without it the DAC still feeds AC0 and ADC0.
    output_to_pin: bool = true,
    /// CTRLA.RUNSTDBY.
    run_standby: bool = false,
    initial_value: u10 = 0,
};

/// Configure and enable DAC0.
///
/// DS40002413 section 34.3.1 "Initialization", page 522: the pin used for the
/// DAC output must have its digital input buffer disabled and its pull-up off.
pub fn configure(config: Config) void {
    regs.write(regs.dac0.ctrla, 0);
    vref.set_dac0_reference(config.reference);

    if (config.output_to_pin) {
        gpio.set_direction(output_pin, .input);
        gpio.configure(output_pin, .{ .sense = .input_disable });
    }

    set_value(config.initial_value);

    var ctrla: u8 = regs.bit(regs.dac0.enable);
    if (config.output_to_pin) ctrla |= regs.bit(regs.dac0.outen);
    if (config.run_standby) ctrla |= regs.bit(regs.dac0.runstdby);
    regs.write(regs.dac0.ctrla, ctrla);
}

pub fn disable() void {
    regs.write(regs.dac0.ctrla, 0);
}

/// Set the output level.
///
/// DATA is left-aligned in a 16-bit register (mask 0xFFC0), so the 10-bit
/// value is shifted up by six rather than written as-is.
pub fn set_value(value: u10) void {
    regs.mem16(regs.dac0.data).* = @as(u16, value) << 6;
}

/// Set the output as a fraction of the reference, in millivolts.
///
/// Returns false if the request exceeds what the configured reference can
/// produce.
pub fn set_millivolts(millivolts: u32, reference: vref.Reference) bool {
    const full_scale = reference.millivolts() orelse return false;
    if (millivolts > full_scale) return false;
    const value = (millivolts * (@as(u32, max_value) + 1)) / full_scale;
    set_value(@intCast(@min(value, max_value)));
    return true;
}
