//! VREF - Voltage Reference.
//!
//! DS40002413 section 21 "VREF - Voltage Reference", page 210.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=210
//!
//! Unlike tinyAVR/megaAVR-0, which packed every reference selection into a
//! single VREF.CTRLA, AVR Dx gives the ADC, the DAC and the analog comparator
//! one register each, so they can use different references at the same time.

const regs = @import("registers.zig");

/// The REFSEL encoding, shared by ADC0REF, DAC0REF and ACREF.
///
/// Note that 0x04 is not a valid encoding on this family -- the internal
/// references jump from 2.500V to VDD.
pub const Reference = enum(u8) {
    internal_1v024 = 0x0,
    internal_2v048 = 0x1,
    internal_4v096 = 0x2,
    internal_2v500 = 0x3,
    /// The supply rail. Accuracy is only as good as VDD.
    vdd = 0x5,
    /// External reference on the VREFA pin.
    external = 0x6,

    /// Nominal reference voltage in millivolts, or null when it is not a
    /// fixed known value (VDD and the external pin).
    pub fn millivolts(r: Reference) ?u32 {
        return switch (r) {
            .internal_1v024 => 1024,
            .internal_2v048 => 2048,
            .internal_2v500 => 2500,
            .internal_4v096 => 4096,
            .vdd, .external => null,
        };
    }
};

/// Select the ADC0 reference.
///
/// `always_on` keeps the reference powered between conversions, trading
/// current for skipping the start-up delay -- see
/// DS40002413 section 21.3.1 "Initialization", page 210.
pub fn set_adc0_reference(reference: Reference) void {
    regs.write(regs.vref.adc0ref, @intFromEnum(reference));
}

pub fn set_adc0_reference_always_on(reference: Reference, always_on: bool) void {
    regs.write(
        regs.vref.adc0ref,
        @intFromEnum(reference) | (if (always_on) regs.bit(regs.vref.alwayson) else 0),
    );
}

pub fn set_dac0_reference(reference: Reference) void {
    regs.write(regs.vref.dac0ref, @intFromEnum(reference));
}

pub fn set_dac0_reference_always_on(reference: Reference, always_on: bool) void {
    regs.write(
        regs.vref.dac0ref,
        @intFromEnum(reference) | (if (always_on) regs.bit(regs.vref.alwayson) else 0),
    );
}

pub fn set_ac_reference(reference: Reference) void {
    regs.write(regs.vref.acref, @intFromEnum(reference));
}

pub fn set_ac_reference_always_on(reference: Reference, always_on: bool) void {
    regs.write(
        regs.vref.acref,
        @intFromEnum(reference) | (if (always_on) regs.bit(regs.vref.alwayson) else 0),
    );
}
