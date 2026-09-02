const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const CLKCTRL = extern struct {
    /// Clock Failure Detect Source select
    pub const CLKCTRL_CFDSRC = enum(u2) {
        /// Main Clock
        CLKMAIN = 0x0,
        /// XOSCHF
        XOSCHF = 0x1,
        /// XOSC32K
        XOSC32K = 0x2,
        _,
    };

    /// Clock select
    pub const CLKCTRL_CLKSEL = enum(u3) {
        /// Internal high-frequency oscillator
        OSCHF = 0x0,
        /// Internal 32.768 kHz oscillator
        OSC32K = 0x1,
        /// 32.768 kHz crystal oscillator
        XOSC32K = 0x2,
        /// External clock
        EXTCLK = 0x3,
        _,
    };

    /// Crystal startup time select
    pub const CLKCTRL_CSUT = enum(u2) {
        /// 1k cycles
        @"1K" = 0x0,
        /// 16k cycles
        @"16K" = 0x1,
        /// 32k cycles
        @"32K" = 0x2,
        /// 64k cycles
        @"64K" = 0x3,
    };

    /// Start-up Time Select
    pub const CLKCTRL_CSUTHF = enum(u2) {
        /// 256 XOSCHF cycles
        @"256" = 0x0,
        /// 1K XOSCHF cycles
        @"1K" = 0x1,
        /// 4K XOSCHF cycles
        @"4K" = 0x2,
        _,
    };

    /// Frequency Range select
    pub const CLKCTRL_FRQRANGE = enum(u2) {
        /// Max 8 MHz XTAL Frequency
        @"8M" = 0x0,
        /// Max 16 MHz XTAL Frequency
        @"16M" = 0x1,
        /// Max 24 MHz XTAL Frequency
        @"24M" = 0x2,
        /// Max 32 MHz XTAL Frequency
        @"32M" = 0x3,
    };

    /// Frequency select
    pub const CLKCTRL_FRQSEL = enum(u4) {
        /// 1 MHz system clock
        @"1M" = 0x0,
        /// 2 MHz system clock
        @"2M" = 0x1,
        /// 3 MHz system clock
        @"3M" = 0x2,
        /// 4 MHz system clock (default)
        @"4M" = 0x3,
        /// 8 MHz system clock
        @"8M" = 0x5,
        /// 12 MHz system clock
        @"12M" = 0x6,
        /// 16 MHz system clock
        @"16M" = 0x7,
        /// 20 MHz system clock
        @"20M" = 0x8,
        /// 24 MHz system clock
        @"24M" = 0x9,
        _,
    };

    /// Interrupt type select
    pub const CLKCTRL_INTTYPE = enum(u1) {
        /// Regular Interrupt
        INT = 0x0,
        /// NMI
        NMI = 0x1,
    };

    /// Multiplication factor select
    pub const CLKCTRL_MULFAC = enum(u2) {
        /// PLL is disabled
        DISABLE = 0x0,
        /// 2 x multiplication factor
        @"2x" = 0x1,
        /// 3 x multiplication factor
        @"3x" = 0x2,
        _,
    };

    /// Prescaler division select
    pub const CLKCTRL_PDIV = enum(u4) {
        /// 2X
        @"2X" = 0x0,
        /// 4X
        @"4X" = 0x1,
        /// 8X
        @"8X" = 0x2,
        /// 16X
        @"16X" = 0x3,
        /// 32X
        @"32X" = 0x4,
        /// 64X
        @"64X" = 0x5,
        /// 6X
        @"6X" = 0x8,
        /// 10X
        @"10X" = 0x9,
        /// 12X
        @"12X" = 0xa,
        /// 24X
        @"24X" = 0xb,
        /// 48X
        @"48X" = 0xc,
        _,
    };

    /// External Source Select
    pub const CLKCTRL_SELHF = enum(u1) {
        /// External Crystal
        XTAL = 0x0,
        /// External clock on XTALHF1 pin
        EXTCLOCK = 0x1,
    };

    /// Source select
    pub const CLKCTRL_SOURCE = enum(u1) {
        /// High frequency internal oscillator as PLL source
        OSCHF = 0x0,
        /// High frequency external clock or external high frequency oscillator as PLL source
        XOSCHF = 0x1,
    };

    /// MCLK Control A
    /// offset: 0x00
    MCLKCTRLA: mmio.Mmio(packed struct(u8) {
        /// Clock select
        CLKSEL: CLKCTRL_CLKSEL,
        reserved7: u4 = 0,
        /// System clock out
        CLKOUT: u1,
    }),
    /// MCLK Control B
    /// offset: 0x01
    MCLKCTRLB: mmio.Mmio(packed struct(u8) {
        /// Prescaler enable
        PEN: u1,
        /// Prescaler division
        PDIV: CLKCTRL_PDIV,
        padding: u3 = 0,
    }),
    /// MCLK Control C
    /// offset: 0x02
    MCLKCTRLC: mmio.Mmio(packed struct(u8) {
        /// Clock Failure Detect Enable
        CFDEN: u1,
        /// Clock Failure Detect Test
        CFDTST: u1,
        /// Clock Failure Detect Source
        CFDSRC: CLKCTRL_CFDSRC,
        padding: u4 = 0,
    }),
    /// MCLK Interrupt Control
    /// offset: 0x03
    MCLKINTCTRL: mmio.Mmio(packed struct(u8) {
        /// Clock Failure Detect Interrupt Enable
        CFD: u1,
        reserved7: u6 = 0,
        /// Interrupt type
        INTTYPE: CLKCTRL_INTTYPE,
    }),
    /// MCLK Interrupt Flags
    /// offset: 0x04
    MCLKINTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Clock Failure Detect Interrupt Flag
        CFD: u1,
        padding: u7 = 0,
    }),
    /// MCLK Status
    /// offset: 0x05
    MCLKSTATUS: mmio.Mmio(packed struct(u8) {
        /// System Oscillator changing
        SOSC: u1,
        /// High frequency oscillator status
        OSCHFS: u1,
        /// 32KHz oscillator status
        OSC32KS: u1,
        /// 32.768 kHz Crystal Oscillator status
        XOSC32KS: u1,
        /// External Clock status
        EXTS: u1,
        /// PLL oscillator status
        PLLS: u1,
        padding: u2 = 0,
    }),
    /// offset: 0x06
    reserved6: [2]u8,
    /// OSCHF Control A
    /// offset: 0x08
    OSCHFCTRLA: mmio.Mmio(packed struct(u8) {
        /// Autotune
        AUTOTUNE: u1,
        reserved2: u1 = 0,
        /// Frequency select
        FRQSEL: CLKCTRL_FRQSEL,
        reserved7: u1 = 0,
        /// Run standby
        RUNSTDBY: u1,
    }),
    /// OSCHF Tune
    /// offset: 0x09
    OSCHFTUNE: mmio.Mmio(packed struct(u8) {
        /// Tune
        TUNE: u8,
    }),
    /// offset: 0x0a
    reserved10: [6]u8,
    /// PLL Control A
    /// offset: 0x10
    PLLCTRLA: mmio.Mmio(packed struct(u8) {
        /// Multiplication factor
        MULFAC: CLKCTRL_MULFAC,
        reserved6: u4 = 0,
        /// Source
        SOURCE: CLKCTRL_SOURCE,
        /// Run standby
        RUNSTDBY: u1,
    }),
    /// offset: 0x11
    reserved17: [7]u8,
    /// OSC32K Control A
    /// offset: 0x18
    OSC32KCTRLA: mmio.Mmio(packed struct(u8) {
        reserved7: u7 = 0,
        /// Run standby
        RUNSTDBY: u1,
    }),
    /// offset: 0x19
    reserved25: [3]u8,
    /// XOSC32K Control A
    /// offset: 0x1c
    XOSC32KCTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Low power mode
        LPMODE: u1,
        /// Select
        SEL: u1,
        reserved4: u1 = 0,
        /// Crystal startup time
        CSUT: CLKCTRL_CSUT,
        reserved7: u1 = 0,
        /// Run standby
        RUNSTDBY: u1,
    }),
    /// offset: 0x1d
    reserved29: [3]u8,
    /// XOSC HF Control A
    /// offset: 0x20
    XOSCHFCTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// External Source Select
        SELHF: CLKCTRL_SELHF,
        /// Frequency Range
        FRQRANGE: CLKCTRL_FRQRANGE,
        /// Start-up Time Select
        CSUTHF: CLKCTRL_CSUTHF,
        reserved7: u1 = 0,
        /// Run Standby
        RUNSTBY: u1,
    }),
};
