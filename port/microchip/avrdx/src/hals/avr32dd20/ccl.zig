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

const regs = @import("registers.zig");

pub const Lut = enum(u2) {
    lut0 = 0,
    lut1 = 1,
    lut2 = 2,
    /// No pin on the 20-pin package; usable as an internal term.
    lut3 = 3,

    fn ctrla(l: Lut) u16 {
        return regs.ccl.lut0ctrla + @as(u16, @intFromEnum(l)) * regs.ccl.lut_stride;
    }

    fn ctrlb(l: Lut) u16 {
        return l.ctrla() + 1;
    }

    fn ctrlc(l: Lut) u16 {
        return l.ctrla() + 2;
    }

    fn truth(l: Lut) u16 {
        return l.ctrla() + 3;
    }
};

/// LUTnCTRLB.INSEL0 - sources for the LUT's first input.
///
/// The peripheral each numeric value refers to differs per input index, which
/// is why there are three separate enums rather than one shared one.
pub const Input0 = enum(u8) {
    /// Tied low.
    masked = 0x0,
    /// This LUT's own output, for building sequential logic.
    feedback = 0x1,
    /// The next LUT's output.
    link = 0x2,
    event_a = 0x3,
    event_b = 0x4,
    /// The LUTn-IN0 pin (PA0 for LUT0).
    pin = 0x5,
    ac0 = 0x6,
    zcd3 = 0x7,
    usart0_txd = 0x8,
    spi0_mosi = 0x9,
    tca0_wo0 = 0xA,
    tcb0_wo = 0xB,
    tcd0_woa = 0xC,
};

/// LUTnCTRLB.INSEL1.
pub const Input1 = enum(u8) {
    masked = 0x0,
    feedback = 0x1,
    link = 0x2,
    event_a = 0x3,
    event_b = 0x4,
    /// The LUTn-IN1 pin (PA1 for LUT0, PC1 for LUT1).
    pin = 0x5,
    ac0 = 0x6,
    zcd3 = 0x7,
    usart1_txd = 0x8,
    spi0_mosi = 0x9,
    tca0_wo1 = 0xA,
    tcb1_wo = 0xB,
    tcd0_wob = 0xC,
};

/// LUTnCTRLC.INSEL2.
pub const Input2 = enum(u8) {
    masked = 0x0,
    feedback = 0x1,
    link = 0x2,
    event_a = 0x3,
    event_b = 0x4,
    /// The LUTn-IN2 pin (PA2 for LUT0, PC2 for LUT1).
    pin = 0x5,
    ac0 = 0x6,
    zcd3 = 0x7,
    spi0_sck = 0x9,
    tca0_wo2 = 0xA,
    tcd0_woc = 0xC,
};

/// LUTnCTRLA.CLKSRC - clock for the filter, edge detector and sequential
/// element. Irrelevant for purely combinational use.
pub const ClockSource = enum(u8) {
    clk_per = 0x0,
    /// Whatever INSEL2 selects.
    in2 = 0x1,
    oschf = 0x4,
    osc32k = 0x5,
    osc1k = 0x6,
};

/// LUTnCTRLA.FILTSEL - debounce the LUT output.
pub const Filter = enum(u8) {
    none = 0x0,
    /// Two-cycle synchronizer.
    synchronizer = 0x1,
    /// Four-cycle digital filter.
    filter = 0x2,
};

/// SEQCTRLn.SEQSEL - the sequential element shared by an even/odd LUT pair.
pub const Sequential = enum(u8) {
    disabled = 0x0,
    d_flip_flop = 0x1,
    jk_flip_flop = 0x2,
    d_latch = 0x3,
    rs_latch = 0x4,
};

pub const LutConfig = struct {
    input0: Input0 = .masked,
    input1: Input1 = .masked,
    input2: Input2 = .masked,
    /// Truth table, indexed by `(in2 << 2) | (in1 << 1) | in0`. Bit n of this
    /// byte is the output for input combination n -- so 0b1000_0000 is a
    /// three-input AND and 0b1111_1110 is a three-input OR.
    truth_table: u8,
    clock: ClockSource = .clk_per,
    filter: Filter = .none,
    /// LUTnCTRLA.EDGEDET - emit a one-clock pulse on each rising edge of the
    /// LUT output instead of the level.
    edge_detect: bool = false,
    /// LUTnCTRLA.OUTEN - drive the LUT's output pin.
    output_to_pin: bool = false,
};

/// Configure one LUT. Enable the peripheral with `enable()` afterwards.
///
/// DS40002413 section 31.3.2 "Initialization", page 462: LUTnCTRLA.ENABLE must
/// be clear while INSEL and TRUTH are being written, which is what the leading
/// zero-write here guarantees.
pub fn configure_lut(lut: Lut, config: LutConfig) void {
    regs.write(lut.ctrla(), 0);

    regs.write(
        lut.ctrlb(),
        @intFromEnum(config.input0) | (@as(u8, @intFromEnum(config.input1)) << 4),
    );
    regs.write(lut.ctrlc(), @intFromEnum(config.input2));
    regs.write(lut.truth(), config.truth_table);

    var ctrla: u8 = regs.bit(regs.ccl.lut_enable) |
        (@as(u8, @intFromEnum(config.clock)) << 1) |
        (@as(u8, @intFromEnum(config.filter)) << 4);
    if (config.output_to_pin) ctrla |= regs.bit(regs.ccl.lut_output_enable);
    if (config.edge_detect) ctrla |= regs.bit(regs.ccl.lut_edge_detect);
    regs.write(lut.ctrla(), ctrla);
}

pub fn disable_lut(lut: Lut) void {
    regs.write(lut.ctrla(), 0);
}

/// Attach a sequential element to a LUT pair. `pair` 0 covers LUT0/LUT1,
/// `pair` 1 covers LUT2/LUT3.
///
/// DS40002413 section 31.3.3.3 "Sequential Logic", page 465.
pub fn configure_sequential(pair: u1, sequential: Sequential) void {
    const address = if (pair == 0) regs.ccl.seqctrl0 else regs.ccl.seqctrl1;
    regs.write(address, @intFromEnum(sequential));
}

/// Enable the CCL peripheral. Individual LUTs also need their own ENABLE,
/// which `configure_lut` sets.
pub fn enable(run_standby: bool) void {
    regs.write(
        regs.ccl.ctrla,
        regs.bit(regs.ccl.enable) | (if (run_standby) regs.bit(regs.ccl.runstdby) else 0),
    );
}

pub fn disable() void {
    regs.write(regs.ccl.ctrla, 0);
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
