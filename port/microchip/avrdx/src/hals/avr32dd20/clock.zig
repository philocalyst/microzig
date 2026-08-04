//! CLKCTRL - main clock source, prescaler, PLL and clock failure detection.
//!
//! DS40002413 section 12 "CLKCTRL - Clock Controller", page 88.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=88
//!
//! Every writable register in this module is CCP-protected except OSCHFTUNE,
//! so nearly all writes funnel through `ccp.write_io`. See the table in
//! `ccp.zig` for the exact set (DS40002413 Table 12-1, page 96).

const regs = @import("registers.zig");
const ccp = @import("ccp.zig");

/// CLKCTRL.MCLKCTRLA.CLKSEL - which oscillator drives CLK_MAIN.
pub const Source = enum(u8) {
    /// Internal high-frequency oscillator (the reset default).
    oschf = 0x0,
    /// Internal 32.768 kHz oscillator.
    osc32k = 0x1,
    /// External 32.768 kHz crystal oscillator.
    xosc32k = 0x2,
    /// External clock on the EXTCLK pin (PA0).
    extclk = 0x3,
};

/// CLKCTRL.OSCHFCTRLA.FRQSEL - internal high-frequency oscillator frequency.
///
/// Note the gap: there is no 6 MHz setting, which is why this cannot be a
/// dense enum. 4 MHz is the value after reset.
pub const InternalFrequency = enum(u8) {
    mhz1 = 0x0,
    mhz2 = 0x1,
    mhz3 = 0x2,
    mhz4 = 0x3,
    mhz8 = 0x5,
    mhz12 = 0x6,
    mhz16 = 0x7,
    mhz20 = 0x8,
    mhz24 = 0x9,

    /// Nominal frequency in Hz, useful for deriving baud rates and delays.
    pub fn hz(f: InternalFrequency) u32 {
        return switch (f) {
            .mhz1 => 1_000_000,
            .mhz2 => 2_000_000,
            .mhz3 => 3_000_000,
            .mhz4 => 4_000_000,
            .mhz8 => 8_000_000,
            .mhz12 => 12_000_000,
            .mhz16 => 16_000_000,
            .mhz20 => 20_000_000,
            .mhz24 => 24_000_000,
        };
    }
};

/// CLKCTRL.MCLKCTRLB.PDIV - main clock prescaler division factor.
pub const Prescaler = enum(u8) {
    div2 = 0x00,
    div4 = 0x01,
    div8 = 0x02,
    div16 = 0x03,
    div32 = 0x04,
    div64 = 0x05,
    div6 = 0x08,
    div10 = 0x09,
    div12 = 0x0A,
    div24 = 0x0B,
    div48 = 0x0C,

    pub fn divisor(p: Prescaler) u8 {
        return switch (p) {
            .div2 => 2,
            .div4 => 4,
            .div6 => 6,
            .div8 => 8,
            .div10 => 10,
            .div12 => 12,
            .div16 => 16,
            .div24 => 24,
            .div32 => 32,
            .div48 => 48,
            .div64 => 64,
        };
    }
};

/// CLKCTRL.PLLCTRLA.MULFAC.
pub const PllMultiplier = enum(u8) {
    disabled = 0x0,
    mul2 = 0x1,
    mul3 = 0x2,
};

/// CLKCTRL.PLLCTRLA.SOURCE.
pub const PllSource = enum(u8) {
    oschf = 0x0,
    xoschf = 0x1,
};

/// CLKCTRL.MCLKCTRLC.CFDSRC - which clock the failure detector watches.
pub const CfdSource = enum(u8) {
    clkmain = 0x0,
    xoschf = 0x1,
    xosc32k = 0x2,
};

/// CLKCTRL.XOSCHFCTRLA.FRQRANGE - external crystal frequency range.
pub const CrystalRange = enum(u8) {
    max8mhz = 0x0,
    max16mhz = 0x1,
    max24mhz = 0x2,
    max32mhz = 0x3,
};

/// CLKCTRL.XOSCHFCTRLA.CSUTHF - external HF crystal start-up time.
pub const CrystalStartup = enum(u8) {
    cycles256 = 0x0,
    cycles1k = 0x1,
    cycles4k = 0x2,
};

/// CLKCTRL.XOSC32KCTRLA.CSUT - 32.768 kHz crystal start-up time.
pub const Crystal32kStartup = enum(u8) {
    cycles1k = 0x0,
    cycles16k = 0x1,
    cycles32k = 0x2,
    cycles64k = 0x3,
};

// -- Main clock --------------------------------------------------------------

/// Select the source for CLK_MAIN. `clock_out` mirrors CLK_MAIN on PA7.
///
/// DS40002413 section 12.3.2 "Main Clock Selection and Prescaler", page 90:
/// CLKSEL selects the main clock source; the switch is glitchless and takes
/// effect once MCLKSTATUS.SOSC clears, so poll `switching()` before assuming
/// the new source is live.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=90
pub fn set_source(source: Source, clock_out: bool) void {
    const value = @intFromEnum(source) | (if (clock_out) regs.bit(regs.clkctrl.clkout) else 0);
    ccp.write_io(regs.clkctrl.mclkctrla, value);
    while (switching()) {}
}

/// Enable the main clock prescaler with the given division factor.
///
/// PDIV occupies MCLKCTRLB bits 4:1, so the enum value is shifted into place
/// and combined with PEN. DS40002413 section 12.5.2 "Main Clock Control B",
/// page 99.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=99
pub fn set_prescaler(prescaler: Prescaler) void {
    ccp.write_io(
        regs.clkctrl.mclkctrlb,
        (@intFromEnum(prescaler) << 1) | regs.bit(regs.clkctrl.pen),
    );
}

/// Run CLK_PER at CLK_MAIN, bypassing the prescaler.
pub fn disable_prescaler() void {
    ccp.write_io(regs.clkctrl.mclkctrlb, 0);
}

/// True while the main clock is still switching between sources
/// (MCLKSTATUS.SOSC).
pub fn switching() bool {
    return (regs.read(regs.clkctrl.mclkstatus) & regs.bit(regs.clkctrl.sosc)) != 0;
}

// -- Internal oscillators ----------------------------------------------------

/// Select the internal high-frequency oscillator frequency.
///
/// FRQSEL sits in OSCHFCTRLA bits 5:2. `autotune` locks OSCHF to XOSC32K when
/// that oscillator is running; `run_standby` forces the oscillator to keep
/// running in standby sleep.
///
/// DS40002413 section 12.5.7 "Internal High-Frequency Oscillator Control A",
/// page 104.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=104
pub fn set_internal_frequency(
    frequency: InternalFrequency,
    options: struct { autotune: bool = false, run_standby: bool = false },
) void {
    var value: u8 = @intFromEnum(frequency) << 2;
    if (options.autotune) value |= regs.bit(regs.clkctrl.autotune);
    if (options.run_standby) value |= regs.bit(regs.clkctrl.runstdby);
    ccp.write_io(regs.clkctrl.oschfctrla, value);

    // Only wait for the oscillator to restabilize if it is actually running.
    // OSCHFS never sets while CLK_MAIN is driven from another source and
    // nothing else has requested OSCHF, so an unconditional spin would hang.
    if (current_source() == .oschf) {
        while (!internal_hf_stable()) {}
    }
}

/// Read back the current CLK_MAIN source from MCLKCTRLA.CLKSEL.
///
/// CLKSEL is a three-bit field but only 0..3 are defined, so mask to two bits
/// rather than risk an out-of-range `@enumFromInt` on a reserved encoding.
pub fn current_source() Source {
    return @enumFromInt(regs.read(regs.clkctrl.mclkctrla) & 0x03);
}

/// Apply a manual tuning offset to OSCHF. Signed, -32..31 around the factory
/// calibration. DS40002413 section 12.3.6 "Manual Tuning and Auto-Tune",
/// page 93.
///
/// OSCHFTUNE is the one writable CLKCTRL register that is *not* CCP-protected:
/// it is absent from Table 12-1, and its register description (section 12.5.8,
/// page 105) reads `Property: -`. A plain store is all it needs.
pub fn tune_internal(offset: i8) void {
    regs.write(regs.clkctrl.oschftune, @bitCast(offset));
}

/// Keep the internal 32.768 kHz oscillator running in standby sleep.
pub fn set_osc32k_run_standby(enable: bool) void {
    ccp.write_io(regs.clkctrl.osc32kctrla, if (enable) regs.bit(regs.clkctrl.runstdby) else 0);
}

pub fn internal_hf_stable() bool {
    return (regs.read(regs.clkctrl.mclkstatus) & regs.bit(regs.clkctrl.oschfs)) != 0;
}

pub fn internal_32k_stable() bool {
    return (regs.read(regs.clkctrl.mclkstatus) & regs.bit(regs.clkctrl.osc32ks)) != 0;
}

// -- External oscillators ----------------------------------------------------

/// Start the external 32.768 kHz crystal oscillator.
///
/// `external_clock` selects a digital clock on XTAL32K1 instead of a crystal
/// (SEL bit); `low_power` picks the reduced swing driver (LPMODE).
///
/// DS40002413 section 12.5.11 "External 32.768 kHz Crystal Oscillator Control
/// A", page 108. The register is write-locked while ENABLE is set, so this
/// disables the oscillator before reconfiguring it.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=108
pub fn enable_xosc32k(options: struct {
    startup: Crystal32kStartup = .cycles1k,
    external_clock: bool = false,
    low_power: bool = false,
    run_standby: bool = false,
}) void {
    ccp.write_io(regs.clkctrl.xosc32kctrla, 0);

    var value: u8 = @as(u8, @intFromEnum(options.startup)) << 4;
    if (options.low_power) value |= regs.bit(1);
    if (options.external_clock) value |= regs.bit(2);
    if (options.run_standby) value |= regs.bit(regs.clkctrl.runstdby);
    ccp.write_io(regs.clkctrl.xosc32kctrla, value);

    ccp.write_io(regs.clkctrl.xosc32kctrla, value | regs.bit(regs.clkctrl.xosc_enable));
}

pub fn disable_xosc32k() void {
    ccp.write_io(regs.clkctrl.xosc32kctrla, 0);
}

pub fn xosc32k_stable() bool {
    return (regs.read(regs.clkctrl.mclkstatus) & regs.bit(regs.clkctrl.xosc32ks)) != 0;
}

/// Start the external high-frequency crystal oscillator, or accept a digital
/// clock on XTALHF1 when `external_clock` is set.
///
/// DS40002413 section 12.5.12 "External High-Frequency Oscillator Control A",
/// page 110.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=110
pub fn enable_xoschf(options: struct {
    range: CrystalRange = .max16mhz,
    startup: CrystalStartup = .cycles256,
    external_clock: bool = false,
    run_standby: bool = false,
}) void {
    var value: u8 = (@as(u8, @intFromEnum(options.range)) << 2) |
        (@as(u8, @intFromEnum(options.startup)) << 4);
    if (options.external_clock) value |= regs.bit(1);
    if (options.run_standby) value |= regs.bit(regs.clkctrl.runstdby);
    ccp.write_io(regs.clkctrl.xoschfctrla, value | regs.bit(regs.clkctrl.xosc_enable));
}

pub fn disable_xoschf() void {
    ccp.write_io(regs.clkctrl.xoschfctrla, 0);
}

// -- PLL ---------------------------------------------------------------------

/// Configure the PLL. The PLL output only feeds TCD0 on this family -- it is
/// not selectable as CLK_MAIN.
///
/// DS40002413 section 12.3.5 "Phase-Locked Loop (PLL)", page 93.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=93
pub fn configure_pll(
    multiplier: PllMultiplier,
    source: PllSource,
    options: struct { run_standby: bool = false },
) void {
    var value: u8 = @intFromEnum(multiplier);
    if (source == .xoschf) value |= regs.bit(6);
    if (options.run_standby) value |= regs.bit(regs.clkctrl.runstdby);
    ccp.write_io(regs.clkctrl.pllctrla, value);
}

pub fn pll_stable() bool {
    return (regs.read(regs.clkctrl.mclkstatus) & regs.bit(regs.clkctrl.plls)) != 0;
}

// -- Clock failure detection -------------------------------------------------

/// Enable the clock failure detector.
///
/// When the watched clock stops, the device switches CLK_MAIN back to OSCHF
/// and raises the CFD interrupt (as an NMI when `non_maskable` is set, which
/// cannot be disabled again until reset).
///
/// DS40002413 section 12.3.7 "Clock Failure Detection (CFD)", page 93.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=93
pub fn enable_cfd(source: CfdSource, options: struct { non_maskable: bool = false }) void {
    ccp.write_io(
        regs.clkctrl.mclkctrlc,
        regs.bit(regs.clkctrl.cfden) | (@as(u8, @intFromEnum(source)) << 2),
    );
    ccp.write_io(
        regs.clkctrl.mclkintctrl,
        regs.bit(0) | (if (options.non_maskable) regs.bit(7) else 0),
    );
}

pub fn cfd_triggered() bool {
    return (regs.read(regs.clkctrl.mclkintflags) & regs.bit(0)) != 0;
}

pub fn clear_cfd_flag() void {
    regs.write(regs.clkctrl.mclkintflags, regs.bit(0));
}

// -- Convenience -------------------------------------------------------------

/// Peripheral clock frequency implied by an internal-oscillator setting.
///
/// Only valid while CLK_MAIN is sourced from OSCHF; there is no register to
/// read an external clock's rate back from.
pub fn peripheral_hz(frequency: InternalFrequency, prescaler: ?Prescaler) u32 {
    const base = frequency.hz();
    return if (prescaler) |p| base / p.divisor() else base;
}

/// Run the part from OSCHF at 24 MHz with the prescaler off.
///
/// This is the fastest configuration reachable without an external crystal.
/// The AVR32DD20 is rated to 24 MHz at 4.5-5.5V and 32 MHz only from an
/// external source; see the ATDF variant `speedmax`, and DS40002413
/// section 12.3.4.1.1 "Internal High-Frequency Oscillator (OSCHF)", page 91.
pub fn use_internal_24mhz() void {
    set_internal_frequency(.mhz24, .{});
    set_source(.oschf, false);
    disable_prescaler();
}
