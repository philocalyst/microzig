//! CLKCTRL - main clock source, prescaler, PLL and clock failure detection.
//!
//! DS40002413 section 12 "CLKCTRL - Clock Controller", page 88.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=88
//!
//! Every writable register in this module is CCP-protected except OSCHFTUNE,
//! so nearly all writes funnel through `ccp.write_io`. See the table in
//! `ccp.zig` for the exact set (DS40002413 Table 12-1, page 96).
//!
//! The register field encodings are re-exported from the generated layer
//! (`microzig.chip.types.peripherals.CLKCTRL`); the enums below only attach
//! this port's friendly names to them.

const microzig = @import("microzig");
const ccp = @import("ccp.zig");
const capabilities = @import("capabilities.zig");

const clkctrl = microzig.chip.peripherals.CLKCTRL;
const gen = microzig.chip.types.peripherals.CLKCTRL;

// The generated layer declares each register's bit fields as an anonymous
// packed struct; pull the types out once so writes are checked against the
// ATDF layout rather than hand-built bytes.
const MCLKCTRLABits = @TypeOf(clkctrl.MCLKCTRLA.read());
const MCLKCTRLBBits = @TypeOf(clkctrl.MCLKCTRLB.read());
const MCLKCTRLCBits = @TypeOf(clkctrl.MCLKCTRLC.read());
const MCLKINTCTRLBits = @TypeOf(clkctrl.MCLKINTCTRL.read());
const OSCHFCTRLABits = @TypeOf(clkctrl.OSCHFCTRLA.read());
const PLLCTRLABits = @TypeOf(clkctrl.PLLCTRLA.read());
const XOSC32KCTRLABits = @TypeOf(clkctrl.XOSC32KCTRLA.read());
const XOSCHFCTRLABits = @TypeOf(clkctrl.XOSCHFCTRLA.read());
const StatusBits = @TypeOf(clkctrl.MCLKSTATUS.read());
const IntFlags = @TypeOf(clkctrl.MCLKINTFLAGS.read());

/// Address of a CLKCTRL register in data space, for CCP writes.
fn reg_addr(comptime field: std.meta.FieldEnum(gen)) u16 {
    return comptime blk: {
        const base = @intFromPtr(clkctrl);
        break :blk switch (field) {
            .MCLKCTRLA => base + @offsetOf(gen, "MCLKCTRLA"),
            .MCLKCTRLB => base + @offsetOf(gen, "MCLKCTRLB"),
            .MCLKCTRLC => base + @offsetOf(gen, "MCLKCTRLC"),
            .MCLKINTCTRL => base + @offsetOf(gen, "MCLKINTCTRL"),
            .OSCHFCTRLA => base + @offsetOf(gen, "OSCHFCTRLA"),
            .PLLCTRLA => base + @offsetOf(gen, "PLLCTRLA"),
            .OSC32KCTRLA => base + @offsetOf(gen, "OSC32KCTRLA"),
            .XOSC32KCTRLA => base + @offsetOf(gen, "XOSC32KCTRLA"),
            .XOSCHFCTRLA => base + @offsetOf(gen, "XOSCHFCTRLA"),
            else => @compileError("register is not CCP-protected"),
        };
    };
}

const std = @import("std");

/// CLKCTRL.MCLKCTRLA.CLKSEL - which oscillator drives CLK_MAIN.
pub const Source = enum(u8) {
    /// Internal high-frequency oscillator (the reset default).
    oschf,
    /// Internal 32.768 kHz oscillator.
    osc32k,
    /// External 32.768 kHz crystal oscillator.
    xosc32k,
    /// External clock on the EXTCLK pin (PA0).
    extclk,

    fn to_field(source: Source) gen.CLKCTRL_CLKSEL {
        return switch (source) {
            .oschf => .OSCHF,
            .osc32k => .OSC32K,
            .xosc32k => .XOSC32K,
            .extclk => .EXTCLK,
        };
    }

    fn from_field(field: gen.CLKCTRL_CLKSEL) ?Source {
        return switch (field) {
            .OSCHF => .oschf,
            .OSC32K => .osc32k,
            .XOSC32K => .xosc32k,
            .EXTCLK => .extclk,
            else => null,
        };
    }
};

/// CLKCTRL.OSCHFCTRLA.FRQSEL - internal high-frequency oscillator frequency.
///
/// Note the gap: there is no 6 MHz setting, which is why this cannot be a
/// dense enum. 4 MHz is the value after reset. The top usable frequency on
/// this part is 24 MHz -- see `capabilities.max_frequency_hz` for why the
/// ATDF's speedmax=32 MHz does not apply to CLK_MAIN.
pub const InternalFrequency = enum(u8) {
    mhz1,
    mhz2,
    mhz3,
    mhz4,
    mhz8,
    mhz12,
    mhz16,
    mhz20,
    /// The fastest rated CPU frequency on this part.
    mhz24,

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

    fn to_field(f: InternalFrequency) gen.CLKCTRL_FRQSEL {
        return switch (f) {
            .mhz1 => .@"1M",
            .mhz2 => .@"2M",
            .mhz3 => .@"3M",
            .mhz4 => .@"4M",
            .mhz8 => .@"8M",
            .mhz12 => .@"12M",
            .mhz16 => .@"16M",
            .mhz20 => .@"20M",
            .mhz24 => .@"24M",
        };
    }
};

/// CLKCTRL.MCLKCTRLB.PDIV - main clock prescaler division factor.
pub const Prescaler = enum(u8) {
    div2,
    div4,
    div6,
    div8,
    div10,
    div12,
    div16,
    div24,
    div32,
    div48,
    div64,

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

    fn to_field(p: Prescaler) gen.CLKCTRL_PDIV {
        return switch (p) {
            .div2 => .@"2X",
            .div4 => .@"4X",
            .div6 => .@"6X",
            .div8 => .@"8X",
            .div10 => .@"10X",
            .div12 => .@"12X",
            .div16 => .@"16X",
            .div24 => .@"24X",
            .div32 => .@"32X",
            .div48 => .@"48X",
            .div64 => .@"64X",
        };
    }
};

/// CLKCTRL.PLLCTRLA.MULFAC.
pub const PllMultiplier = enum(u8) {
    disabled,
    mul2,
    mul3,

    fn to_field(m: PllMultiplier) gen.CLKCTRL_MULFAC {
        return switch (m) {
            .disabled => .DISABLE,
            .mul2 => .@"2x",
            .mul3 => .@"3x",
        };
    }
};

/// CLKCTRL.PLLCTRLA.SOURCE.
pub const PllSource = enum(u8) {
    oschf,
    xoschf,

    fn to_field(s: PllSource) gen.CLKCTRL_SOURCE {
        return switch (s) {
            .oschf => .OSCHF,
            .xoschf => .XOSCHF,
        };
    }
};

/// CLKCTRL.MCLKCTRLC.CFDSRC - which clock the failure detector watches.
pub const CfdSource = enum(u8) {
    clkmain,
    xoschf,
    xosc32k,

    fn to_field(s: CfdSource) gen.CLKCTRL_CFDSRC {
        return switch (s) {
            .clkmain => .CLKMAIN,
            .xoschf => .XOSCHF,
            .xosc32k => .XOSC32K,
        };
    }
};

/// CLKCTRL.XOSCHFCTRLA.FRQRANGE - external crystal frequency range.
pub const CrystalRange = enum(u8) {
    max8mhz,
    max16mhz,
    max24mhz,
    max32mhz,

    fn to_field(r: CrystalRange) gen.CLKCTRL_FRQRANGE {
        return switch (r) {
            .max8mhz => .@"8M",
            .max16mhz => .@"16M",
            .max24mhz => .@"24M",
            .max32mhz => .@"32M",
        };
    }
};

/// CLKCTRL.XOSCHFCTRLA.CSUTHF - external HF crystal start-up time.
pub const CrystalStartup = enum(u8) {
    cycles256,
    cycles1k,
    cycles4k,

    fn to_field(s: CrystalStartup) gen.CLKCTRL_CSUTHF {
        return switch (s) {
            .cycles256 => .@"256",
            .cycles1k => .@"1K",
            .cycles4k => .@"4K",
        };
    }
};

/// CLKCTRL.XOSC32KCTRLA.CSUT - 32.768 kHz crystal start-up time.
pub const Crystal32kStartup = enum(u8) {
    cycles1k,
    cycles16k,
    cycles32k,
    cycles64k,

    fn to_field(s: Crystal32kStartup) gen.CLKCTRL_CSUT {
        return switch (s) {
            .cycles1k => .@"1K",
            .cycles16k => .@"16K",
            .cycles32k => .@"32K",
            .cycles64k => .@"64K",
        };
    }
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
    ccp.write_io(reg_addr(.MCLKCTRLA), @bitCast(MCLKCTRLABits{
        .CLKSEL = source.to_field(),
        .CLKOUT = @intFromBool(clock_out),
    }));
}

/// Enable the main clock prescaler with the given division factor.
///
/// PDIV occupies MCLKCTRLB bits 4:1 alongside PEN. DS40002413 section 12.5.2
/// "Main Clock Control B", page 99.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=99
pub fn set_prescaler(prescaler: Prescaler) void {
    ccp.write_io(reg_addr(.MCLKCTRLB), @bitCast(MCLKCTRLBBits{
        .PEN = 1,
        .PDIV = prescaler.to_field(),
    }));
}

/// Run CLK_PER at CLK_MAIN, bypassing the prescaler.
pub fn disable_prescaler() void {
    ccp.write_io(reg_addr(.MCLKCTRLB), 0);
}

/// True while the main clock is still switching between sources
/// (MCLKSTATUS.SOSC).
pub fn switching() bool {
    return clkctrl.MCLKSTATUS.read().SOSC != 0;
}

// -- Internal oscillators ----------------------------------------------------

/// Select the internal high-frequency oscillator frequency.
///
/// `autotune` locks OSCHF to XOSC32K when that oscillator is running;
/// `run_standby` forces the oscillator to keep running in standby sleep.
///
/// DS40002413 section 12.5.7 "Internal High-Frequency Oscillator Control A",
/// page 104.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=104
pub fn set_internal_frequency(
    frequency: InternalFrequency,
    options: struct { autotune: bool = false, run_standby: bool = false },
) void {
    ccp.write_io(reg_addr(.OSCHFCTRLA), @bitCast(OSCHFCTRLABits{
        .AUTOTUNE = @intFromBool(options.autotune),
        .FRQSEL = frequency.to_field(),
        .RUNSTDBY = @intFromBool(options.run_standby),
    }));

    // Only wait for the oscillator to restabilize if it is actually running.
    // OSCHFS never sets while CLK_MAIN is driven from another source and
    // nothing else has requested OSCHF, so an unconditional spin would hang.
    if (current_source() == .oschf) {
        while (!internal_hf_stable()) {}
    }
}

/// Read back the current CLK_MAIN source from MCLKCTRLA.CLKSEL.
///
/// Reserved encodings read back as `.extclk`-adjacent nonsense; callers that
/// care can check `@intFromEnum` against the generated enum's defined set.
pub fn current_source() Source {
    return Source.from_field(clkctrl.MCLKCTRLA.read().CLKSEL) orelse .oschf;
}

/// Apply a manual tuning offset to OSCHF. Signed, -32..31 around the factory
/// calibration. DS40002413 section 12.3.6 "Manual Tuning and Auto-Tune",
/// page 93.
///
/// OSCHFTUNE is the one writable CLKCTRL register that is *not* CCP-protected:
/// it is absent from Table 12-1, and its register description (section 12.5.8,
/// page 105) reads `Property: -`. A plain store is all it needs.
pub fn tune_internal(offset: i8) void {
    // FACTOR is an 8-bit signed field; the plain u8 store matches it.
    clkctrl.OSCHFTUNE.write_raw(@bitCast(offset));
}

/// Keep the internal 32.768 kHz oscillator running in standby sleep.
pub fn set_osc32k_run_standby(enable: bool) void {
    const Bits = @TypeOf(clkctrl.OSC32KCTRLA.read());
    ccp.write_io(reg_addr(.OSC32KCTRLA), @bitCast(Bits{
        .RUNSTDBY = @intFromBool(enable),
    }));
}

/// True when OSCHF runs and is stable (MCLKSTATUS.OSCHFS).
pub fn internal_hf_stable() bool {
    return clkctrl.MCLKSTATUS.read().OSCHFS != 0;
}

/// True when OSC32K is stable (MCLKSTATUS.OSC32KS).
pub fn internal_32k_stable() bool {
    return clkctrl.MCLKSTATUS.read().OSC32KS != 0;
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
    ccp.write_io(reg_addr(.XOSC32KCTRLA), 0);

    var bits: XOSC32KCTRLABits = .{
        .ENABLE = 0,
        .CSUT = options.startup.to_field(),
        .LPMODE = @intFromBool(options.low_power),
        .SEL = @intFromBool(options.external_clock),
        .RUNSTDBY = @intFromBool(options.run_standby),
    };
    _ = &bits;
    ccp.write_io(reg_addr(.XOSC32KCTRLA), @bitCast(bits));

    bits.ENABLE = 1;
    ccp.write_io(reg_addr(.XOSC32KCTRLA), @bitCast(bits));
}

/// Stop the external 32.768 kHz crystal.
pub fn disable_xosc32k() void {
    ccp.write_io(reg_addr(.XOSC32KCTRLA), 0);
}

/// True when XOSC32K has settled (MCLKSTATUS.XOSC32KS).
pub fn xosc32k_stable() bool {
    return clkctrl.MCLKSTATUS.read().XOSC32KS != 0;
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
    var bits: XOSCHFCTRLABits = .{
        .ENABLE = 0,
        .FRQRANGE = options.range.to_field(),
        .CSUTHF = options.startup.to_field(),
        .SELHF = if (options.external_clock) .EXTCLOCK else .XTAL,
        .RUNSTBY = @intFromBool(options.run_standby),
    };
    _ = &bits;
    bits.ENABLE = 1;
    ccp.write_io(reg_addr(.XOSCHFCTRLA), @bitCast(bits));
}

/// Stop the external high-frequency crystal.
pub fn disable_xoschf() void {
    ccp.write_io(reg_addr(.XOSCHFCTRLA), 0);
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
    ccp.write_io(reg_addr(.PLLCTRLA), @bitCast(PLLCTRLABits{
        .MULFAC = multiplier.to_field(),
        .SOURCE = source.to_field(),
        .RUNSTDBY = @intFromBool(options.run_standby),
    }));
}

/// True when PLL output is locked and stable.
pub fn pll_stable() bool {
    return clkctrl.MCLKSTATUS.read().PLLS != 0;
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
    ccp.write_io(reg_addr(.MCLKCTRLC), @bitCast(MCLKCTRLCBits{
        .CFDEN = 1,
        .CFDTST = 0,
        .CFDSRC = source.to_field(),
    }));
    ccp.write_io(reg_addr(.MCLKINTCTRL), @bitCast(MCLKINTCTRLBits{
        .CFD = 1,
        .INTTYPE = if (options.non_maskable) .NMI else .INT,
    }));
}

/// True when clock-failure detection latched a fault.
pub fn cfd_triggered() bool {
    return clkctrl.MCLKINTFLAGS.read().CFD != 0;
}

/// Clear the CFD flag so future failures are seen again.
pub fn clear_cfd_flag() void {
    clkctrl.MCLKINTFLAGS.write(.{ .CFD = 1 });
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
/// This is the fastest configuration reachable without an external crystal,
/// and the AVR32DD20's rated maximum regardless of source; see
/// `capabilities.max_frequency_hz` and DS40002413 section 12.3.4.1.1
/// "Internal High-Frequency Oscillator (OSCHF)", page 91.
pub fn use_internal_24mhz() void {
    set_internal_frequency(.mhz24, .{});
    set_source(.oschf, false);
    disable_prescaler();
}
