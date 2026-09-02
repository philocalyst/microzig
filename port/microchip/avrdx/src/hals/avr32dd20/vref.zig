//! VREF - Voltage Reference.
//!
//! DS40002413 section 21 "VREF - Voltage Reference", page 210.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=210
//!
//! Unlike tinyAVR/megaAVR-0, which packed every reference selection into a
//! single VREF.CTRLA, AVR Dx gives the ADC, the DAC and the analog comparator
//! one register each, so they can use different references at the same time.

const microzig = @import("microzig");

const vref = microzig.chip.peripherals.VREF;
const gen = microzig.chip.types.peripherals.VREF;

/// The REFSEL encoding, shared by ADC0REF, DAC0REF and ACREF; re-exported
/// from the generated layer.
///
/// Note that 0x04 is not a valid encoding on this family -- the internal
/// references jump from 2.500V to VDD.
pub const Reference = gen.VREF_REFSEL;

/// Nominal reference voltage in millivolts for the fixed references.
pub fn reference_millivolts(r: Reference) ?u32 {
    return switch (r) {
        .@"1V024" => 1024,
        .@"2V048" => 2048,
        .@"2V500" => 2500,
        .@"4V096" => 4096,
        else => null,
    };
}

fn set_ref(comptime reg: anytype, reference: Reference, always_on: bool) void {
    reg.write(.{
        .REFSEL = reference,
        .ALWAYSON = @intFromBool(always_on),
    });
}

/// Select the ADC0 reference.
///
/// `always_on` keeps the reference powered between conversions, trading
/// current for skipping the start-up delay -- see
/// DS40002413 section 21.3.1 "Initialization", page 210.
pub fn set_adc0_reference(reference: Reference) void {
    set_adc0_reference_always_on(reference, false);
}

/// Variant of `set_adc0_reference` with explicit always-on control.
pub fn set_adc0_reference_always_on(reference: Reference, always_on: bool) void {
    set_ref(&vref.ADC0REF, reference, always_on);
}

/// Select the DAC0 reference with a start-up delay per conversion.
pub fn set_dac0_reference(reference: Reference) void {
    set_dac0_reference_always_on(reference, false);
}

/// Select the DAC0 reference, optionally keeping it powered always on.
pub fn set_dac0_reference_always_on(reference: Reference, always_on: bool) void {
    set_ref(&vref.DAC0REF, reference, always_on);
}

/// Select the analog comparator reference.
pub fn set_ac_reference(reference: Reference) void {
    set_ac_reference_always_on(reference, false);
}

/// Select the comparator reference with explicit always-on control.
pub fn set_ac_reference_always_on(reference: Reference, always_on: bool) void {
    set_ref(&vref.ACREF, reference, always_on);
}
