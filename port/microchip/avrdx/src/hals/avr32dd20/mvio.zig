//! MVIO - Multi-Voltage I/O.
//!
//! DS40002413 section 19 "MVIO - Multi-Voltage I/O", page 192.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=192
//!
//! On the AVR32DD20, PORTC (PC1..PC3) is powered from the VDDIO2 pin instead
//! of VDD, so those three pins can talk to a device at a different logic level
//! without external translators. Whether MVIO is active at all is fixed by the
//! FUSE.SYSCFG1.MVSYSCFG fuse, not by software -- this module only reports and
//! reacts to VDDIO2's state.

const regs = @import("registers.zig");

/// FUSE.SYSCFG1.MVSYSCFG, bits 4:3. Read-only from the running application.
pub const SystemConfiguration = enum(u8) {
    /// VDDIO2 is tied to VDD externally; PORTC behaves like any other port.
    single_supply = 0x0,
    /// VDDIO2 is supplied separately. PORTC is only usable while VDDIO2 is
    /// above its threshold.
    dual_supply = 0x1,
    _,
};

/// Read the MVIO fuse setting that this device was programmed with.
pub fn system_configuration() SystemConfiguration {
    return @enumFromInt((regs.read(regs.fuse.syscfg1) & 0x18) >> 3);
}

/// True when VDDIO2 is present and above the MVIO threshold, i.e. when PORTC
/// is actually usable.
///
/// DS40002413 section 19.5.3 "Status", page 199: in single-supply mode this
/// bit reads 1 permanently, so the same code works either way.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=199
pub fn vddio2_ok() bool {
    return (regs.read(regs.mvio.status) & regs.bit(regs.mvio.vddio2s)) != 0;
}

/// Raise an interrupt whenever VDDIO2 crosses its threshold in either
/// direction.
///
/// DS40002413 section 19.3.4 "Interrupts", page 194. Useful for parking PORTC
/// safely when the second supply drops.
pub fn enable_interrupt() void {
    regs.set_bits(regs.mvio.intctrl, regs.bit(regs.mvio.vddio2ie));
}

pub fn disable_interrupt() void {
    regs.clear_bits(regs.mvio.intctrl, regs.bit(regs.mvio.vddio2ie));
}

pub fn interrupt_pending() bool {
    return (regs.read(regs.mvio.intflags) & regs.bit(regs.mvio.vddio2if)) != 0;
}

pub fn clear_interrupt() void {
    regs.write(regs.mvio.intflags, regs.bit(regs.mvio.vddio2if));
}

/// Block until VDDIO2 comes up.
///
/// DS40002413 section 19.3.2.1 "Power Sequencing", page 194: driving a PORTC
/// pin while VDDIO2 is absent is not meaningful, so code that owns PORTC
/// should gate its initialization on this.
pub fn wait_for_vddio2() void {
    while (!vddio2_ok()) {}
}

/// VDDIO2/10 as an ADC input, for measuring the second supply.
///
/// Pair with `adc.Channel.vddio2_div10` and a reference that covers
/// VDDIO2/10; see DS40002413 section 19.3.2.2 "Voltage Measurement", page 194.
pub const measurement_divisor = 10;
