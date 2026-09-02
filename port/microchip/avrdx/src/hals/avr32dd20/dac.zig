//! DAC0 - 10-bit Digital-to-Analog Converter.
//!
//! DS40002413 section 34 "DAC - Digital-to-Analog Converter", page 522.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=522
//!
//! The output buffer drives PD6 on this package. The DAC can also be used
//! purely internally as a reference for the analog comparator or a source for
//! the ADC, in which case leave `output_to_pin` off.

const microzig = @import("microzig");
const gpio = @import("gpio.zig");
const vref = @import("vref.zig");

const dac = microzig.chip.peripherals.DAC0;

/// The output pad, when `Config.output_to_pin` is set.
pub const output_pin = gpio.pins.pd6;

/// DAC0 resolution; DATA is right-aligned on this part.
pub const resolution_bits = 10;
/// Largest code the 10-bit DAC accepts.
pub const max_value: u10 = 1023;

/// DAC output configuration.
pub const Config = struct {
    reference: vref.Reference = .@"2V048",
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
    dac.CTRLA.write(.{
        .ENABLE = 0,
        .OUTEN = 0,
        .RUNSTDBY = 0,
    });
    vref.set_dac0_reference(config.reference);

    if (config.output_to_pin) {
        gpio.set_direction(output_pin, .input);
        gpio.configure(output_pin, .{ .sense = .input_disable });
    }

    set_value(config.initial_value);

    dac.CTRLA.write(.{
        .ENABLE = 1,
        .OUTEN = @intFromBool(config.output_to_pin),
        .RUNSTDBY = @intFromBool(config.run_standby),
    });
}

/// Power down DAC0 and release PD6 from its output driver.
pub fn disable() void {
    dac.CTRLA.write(.{
        .ENABLE = 0,
        .OUTEN = 0,
        .RUNSTDBY = 0,
    });
}

/// Set the output level.
///
/// ATDF/DAC.DATA places the 10-bit value in bits [15:6] (mask 0xFFC0); the
/// generated `DATA` field already encodes that left alignment, so a typed
/// write is enough -- no manual `<< 6`.
/// DS40002413 section 34.5.2 "DATA", page 527.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=527
pub fn set_value(value: u10) void {
    dac.DATA.write(.{ .DATA = value });
}

/// Set the output as a fraction of the reference, in millivolts.
///
/// Returns false if the request exceeds what the configured reference can
/// produce.
pub fn set_millivolts(millivolts: u32, reference: vref.Reference) bool {
    const full_scale = vref.reference_millivolts(reference) orelse return false;
    if (millivolts > full_scale) return false;
    const value = (millivolts * (@as(u32, max_value) + 1)) / full_scale;
    set_value(@intCast(@min(value, max_value)));
    return true;
}
