//! CCL - Configurable Custom Logic.
//!
//! DS40002413 section 31 "CCL - Configurable Custom Logic", page 461.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=461
//!
//! Four three-input look-up tables that run independently of the CPU. Each LUT
//! takes three inputs, applies an eight-entry truth table and produces one
//! output; pairs of LUTs can additionally feed a sequential element (latch,
//! flip-flop). On the 20-pin package LUT0, LUT1 and LUT2 can reach a pin (see
//! `portmux`); LUT3 exists but is internal-only here.
//!
//! The generated layer flattens the four identical LUT register blocks into
//! named registers (`LUT0CTRLA`..`LUT3CTRLC` plus `TRUTH0`..`TRUTH3`); this
//! module indexes them by comptime name while keeping every field value
//! inside the ATDF-derived types.

const std = @import("std");
const microzig = @import("microzig");

const ccl = microzig.chip.peripherals.CCL;
const gen = microzig.chip.types.peripherals.CCL;

/// One of the four look-up table instances.
pub const Lut = enum(u2) {
    lut0 = 0,
    lut1 = 1,
    lut2 = 2,
    /// No pin on the 20-pin package; usable as an internal term.
    lut3 = 3,

    /// Name fragment of this LUT's registers in the generated layer.
    fn prefix(l: Lut) []const u8 {
        return switch (l) {
            .lut0 => "LUT0",
            .lut1 => "LUT1",
            .lut2 => "LUT2",
            .lut3 => "LUT3",
        };
    }
};

/// Comptime name of one of a LUT's registers in the generated layer.
///
/// Register naming there is `LUT{n}CTRLA/B/C` but `TRUTH{n}`, so the TRUTH
/// register breaks the prefix pattern and gets its own case.
fn reg_name(comptime l: Lut, comptime suffix: []const u8) []const u8 {
    if (comptime std.mem.eql(u8, suffix, "TRUTH")) {
        return switch (l) {
            .lut0 => "TRUTH0",
            .lut1 => "TRUTH1",
            .lut2 => "TRUTH2",
            .lut3 => "TRUTH3",
        };
    } else {
        return l.prefix() ++ suffix;
    }
}

/// Field shapes, taken from LUT0's generated types (all four LUTs share them).
const CtrlABits = @TypeOf(ccl.LUT0CTRLA.read());
const CtrlBBits = @TypeOf(ccl.LUT0CTRLB.read());
const CtrlCBits = @TypeOf(ccl.LUT0CTRLC.read());

/// LUTnCTRLB.INSEL0 - sources for the LUT's first input.
pub const Input0 = gen.CCL_INSEL0;
/// LUTnCTRLB.INSEL1.
pub const Input1 = gen.CCL_INSEL1;
/// LUTnCTRLC.INSEL2.
pub const Input2 = gen.CCL_INSEL2;

/// LUTnCTRLA.CLKSRC - clock for the filter, edge detector and sequential
/// element. Irrelevant for purely combinational use.
pub const ClockSource = gen.CCL_CLKSRC;

/// LUTnCTRLA.FILTSEL - debounce the LUT output.
pub const Filter = gen.CCL_FILTSEL;

/// SEQCTRLn.SEQSEL - the sequential element shared by an even/odd LUT pair.
pub const Sequential = gen.CCL_SEQSEL;

/// Inputs and truth table for one LUT.
pub const LutConfig = struct {
    input0: Input0 = .MASK,
    input1: Input1 = .MASK,
    input2: Input2 = .MASK,
    /// Truth table, indexed by `(in2 << 2) | (in1 << 1) | in0`. Bit n of this
    /// byte is the output for input combination n -- so 0b1000_0000 is a
    /// three-input AND and 0b1111_1110 is a three-input OR.
    truth_table: u8,
    clock: ClockSource = .CLKPER,
    filter: Filter = .DISABLE,
    /// LUTnCTRLA.EDGEDET - emit a one-clock pulse on each rising edge of the
    /// LUT output instead of the level.
    edge_detect: bool = false,
    /// LUTnCTRLA.OUTEN - drive the LUT's output pin.
    output_to_pin: bool = false,
};

/// Configure one LUT. Enable the peripheral with `enable()` afterwards.
///
/// DS40002413 section 31.3.1.1 "Enable-Protected Configuration", page 463:
/// LUTnCTRLA.ENABLE must
/// be clear while INSEL and TRUTH are being written, which is what the leading
/// zero-write here guarantees.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=463
pub fn configure_lut(comptime lut: Lut, config: LutConfig) void {
    // Disabled first so INSEL/TRUTH accept writes (section 31.3.1.1).
    @field(ccl, reg_name(lut, "CTRLA")).write_raw(0);

    @field(ccl, reg_name(lut, "CTRLB")).write_raw(@bitCast(CtrlBBits{
        .INSEL0 = config.input0,
        .INSEL1 = config.input1,
    }));
    @field(ccl, reg_name(lut, "CTRLC")).write_raw(@bitCast(CtrlCBits{
        .INSEL2 = config.input2,
    }));
    @field(ccl, reg_name(lut, "TRUTH")).write_raw(config.truth_table);

    @field(ccl, reg_name(lut, "CTRLA")).write_raw(@bitCast(CtrlABits{
        .ENABLE = 1,
        .CLKSRC = config.clock,
        .FILTSEL = config.filter,
        .OUTEN = @intFromBool(config.output_to_pin),
        .EDGEDET = @fromBackingInt(@intCast(@intFromBool(config.edge_detect))),
    }));
}

/// Disable one LUT; other LUTs and the sequencer keep running.
pub fn disable_lut(comptime lut: Lut) void {
    @field(ccl, reg_name(lut, "CTRLA")).write_raw(0);
}

/// Attach a sequential element to a LUT pair. `pair` 0 covers LUT0/LUT1,
/// `pair` 1 covers LUT2/LUT3.
///
/// DS40002413 section 31.3.1.7 "Sequencer Logic", page 467.
pub fn configure_sequential(pair: u1, sequential: Sequential) void {
    switch (pair) {
        0 => ccl.SEQCTRL0.modify(.{ .SEQSEL = sequential }),
        1 => ccl.SEQCTRL1.modify(.{ .SEQSEL = sequential }),
    }
}

/// Enable the CCL peripheral. Individual LUTs also need their own ENABLE,
/// which `configure_lut` sets.
pub fn enable(run_standby: bool) void {
    ccl.CTRLA.write(.{
        .ENABLE = 1,
        .RUNSTDBY = @intFromBool(run_standby),
    });
}

/// Disable the whole peripheral; every LUT output goes low.
pub fn disable() void {
    ccl.CTRLA.write(.{
        .ENABLE = 0,
        .RUNSTDBY = 0,
    });
}

/// Common truth tables.
///
/// Bit `n` of the byte is the output for input combination
/// `n = (in2 << 2) | (in1 << 1) | in0`. The two-input entries are written out
/// over all eight combinations so they stay correct whether or not in2 is
/// masked.
pub const truth = struct {
    /// in0 AND in1: bits 3 and 7.
    pub const and2: u8 = 0b1000_1000;
    /// in0 OR in1: everything except 0 and 4.
    pub const or2: u8 = 0b1110_1110;
    /// in0 XOR in1: bits 1, 2, 5, 6.
    pub const xor2: u8 = 0b0110_0110;
    pub const nand2: u8 = 0b0111_0111;
    pub const nor2: u8 = 0b0001_0001;
    /// All three inputs high: bit 7 only.
    pub const and3: u8 = 0b1000_0000;
    /// Any input high: everything except 0.
    pub const or3: u8 = 0b1111_1110;
    /// Odd parity: bits 1, 2, 4, 7.
    pub const xor3: u8 = 0b1001_0110;
    /// Pass input 0 straight through: bits 1, 3, 5, 7.
    pub const buffer0: u8 = 0b1010_1010;
    /// Invert input 0.
    pub const not0: u8 = 0b0101_0101;
};

test "truth tables" {
    try @import("std").testing.expectEqual(@as(u8, 0b1000_1000), truth.and2);
    try @import("std").testing.expectEqual(@as(u8, 0b1111_1110), truth.or3);
}

// -- Interrupts ---------------------------------------------------------------
//
// DS40002413 section 31.3.2 "Interrupts", page 469.
// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=469
//
// Each LUT output feeds one edge detector whose mode is set independently;
// all four flags OR into the single CCL_INT vector, so a handler must consult
// INTFLAGS to see which LUT fired.

/// INTCTRL0.INTMODEx - which output transition raises the flag for a LUT.
pub const InterruptMode = gen.CCL_INTMODE0;

fn intmode_field(comptime l: Lut) []const u8 {
    return switch (l) {
        .lut0 => "INTMODE0",
        .lut1 => "INTMODE1",
        .lut2 => "INTMODE2",
        .lut3 => "INTMODE3",
    };
}

/// Set the interrupt condition for one LUT (rising, falling or both edges).
///
/// The flag fires on the *filtered/edge-detected* LUT output when that
/// condition holds; with `.INTDISABLE` the source stays silent.
pub fn configure_interrupt(comptime lut: Lut, mode: InterruptMode) void {
    var ctrl = ccl.INTCTRL0.read();
    @field(ctrl, intmode_field(lut)) = mode;
    ccl.INTCTRL0.write(ctrl);
}

/// Silence one LUT's interrupt source.
pub fn disable_interrupt(comptime lut: Lut) void {
    configure_interrupt(lut, .INTDISABLE);
}

/// True when this LUT's interrupt flag is raised.
///
/// INTFLAGS.INT bit i belongs to LUT i.
pub fn interrupt_pending(comptime lut: Lut) bool {
    const mask = @as(u4, 1) << @backingInt(lut);
    return (ccl.INTFLAGS.read().INT & mask) != 0;
}

/// Clear one LUT's interrupt flag. Flags are write-one-to-clear and the
/// register is shared by four sources, so only the selected bit may be
/// written.
pub fn clear_interrupt_flag(comptime lut: Lut) void {
    const mask = @as(u4, 1) << @backingInt(lut);
    ccl.INTFLAGS.write(.{ .INT = mask });
}
