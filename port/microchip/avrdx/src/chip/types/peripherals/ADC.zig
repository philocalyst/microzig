const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const ADC = extern struct {
    /// Conversion mode select
    pub const ADC_CONVMODE = enum(u1) {
        /// Single-Ended mode
        SINGLEENDED = 0x0,
        /// Differential mode
        DIFF = 0x1,
    };

    /// Initial Delay Selection
    pub const ADC_INITDLY = enum(u3) {
        /// Delay 0 CLK_ADC cycles
        DLY0 = 0x0,
        /// Delay 16 CLK_ADC cycles
        DLY16 = 0x1,
        /// Delay 32 CLK_ADC cycles
        DLY32 = 0x2,
        /// Delay 64 CLK_ADC cycles
        DLY64 = 0x3,
        /// Delay 128 CLK_ADC cycles
        DLY128 = 0x4,
        /// Delay 256 CLK_ADC cycles
        DLY256 = 0x5,
        _,
    };

    /// Analog Channel Selection Bits
    pub const ADC_MUXNEG = enum(u7) {
        /// ADC input pin 1
        AIN1 = 0x1,
        /// ADC input pin 2
        AIN2 = 0x2,
        /// ADC input pin 3
        AIN3 = 0x3,
        /// ADC input pin 4
        AIN4 = 0x4,
        /// ADC input pin 5
        AIN5 = 0x5,
        /// ADC input pin 6
        AIN6 = 0x6,
        /// ADC input pin 7
        AIN7 = 0x7,
        /// ADC input pin 16
        AIN16 = 0x10,
        /// ADC input pin 17
        AIN17 = 0x11,
        /// ADC input pin 18
        AIN18 = 0x12,
        /// ADC input pin 19
        AIN19 = 0x13,
        /// ADC input pin 20
        AIN20 = 0x14,
        /// ADC input pin 21
        AIN21 = 0x15,
        /// ADC input pin 22
        AIN22 = 0x16,
        /// ADC input pin 23
        AIN23 = 0x17,
        /// ADC input pin 24
        AIN24 = 0x18,
        /// ADC input pin 25
        AIN25 = 0x19,
        /// ADC input pin 26
        AIN26 = 0x1a,
        /// ADC input pin 27
        AIN27 = 0x1b,
        /// ADC input pin 28
        AIN28 = 0x1c,
        /// ADC input pin 29
        AIN29 = 0x1d,
        /// ADC input pin 30
        AIN30 = 0x1e,
        /// ADC input pin 31
        AIN31 = 0x1f,
        /// Ground
        GND = 0x40,
        /// DAC0
        DAC0 = 0x48,
        _,
    };

    /// Analog Channel Selection Bits
    pub const ADC_MUXPOS = enum(u7) {
        /// ADC input pin 1
        AIN1 = 0x1,
        /// ADC input pin 2
        AIN2 = 0x2,
        /// ADC input pin 3
        AIN3 = 0x3,
        /// ADC input pin 4
        AIN4 = 0x4,
        /// ADC input pin 5
        AIN5 = 0x5,
        /// ADC input pin 6
        AIN6 = 0x6,
        /// ADC input pin 7
        AIN7 = 0x7,
        /// ADC input pin 16
        AIN16 = 0x10,
        /// ADC input pin 17
        AIN17 = 0x11,
        /// ADC input pin 18
        AIN18 = 0x12,
        /// ADC input pin 19
        AIN19 = 0x13,
        /// ADC input pin 20
        AIN20 = 0x14,
        /// ADC input pin 21
        AIN21 = 0x15,
        /// ADC input pin 22
        AIN22 = 0x16,
        /// ADC input pin 23
        AIN23 = 0x17,
        /// ADC input pin 24
        AIN24 = 0x18,
        /// ADC input pin 25
        AIN25 = 0x19,
        /// ADC input pin 26
        AIN26 = 0x1a,
        /// ADC input pin 27
        AIN27 = 0x1b,
        /// ADC input pin 28
        AIN28 = 0x1c,
        /// ADC input pin 29
        AIN29 = 0x1d,
        /// ADC input pin 30
        AIN30 = 0x1e,
        /// ADC input pin 31
        AIN31 = 0x1f,
        /// Ground
        GND = 0x40,
        /// Temperature sensor
        TEMPSENSE = 0x42,
        /// VDD/10
        VDDDIV10 = 0x44,
        /// VDDIO2/10
        VDDIO2DIV10 = 0x45,
        /// DAC0
        DAC0 = 0x48,
        /// DACREF0
        DACREF0 = 0x49,
        _,
    };

    /// Clock Pre-scaler select
    pub const ADC_PRESC = enum(u4) {
        /// CLK_PER divided by 2
        DIV2 = 0x0,
        /// CLK_PER divided by 4
        DIV4 = 0x1,
        /// CLK_PER divided by 8
        DIV8 = 0x2,
        /// CLK_PER divided by 12
        DIV12 = 0x3,
        /// CLK_PER divided by 16
        DIV16 = 0x4,
        /// CLK_PER divided by 20
        DIV20 = 0x5,
        /// CLK_PER divided by 24
        DIV24 = 0x6,
        /// CLK_PER divided by 28
        DIV28 = 0x7,
        /// CLK_PER divided by 32
        DIV32 = 0x8,
        /// CLK_PER divided by 48
        DIV48 = 0x9,
        /// CLK_PER divided by 64
        DIV64 = 0xa,
        /// CLK_PER divided by 96
        DIV96 = 0xb,
        /// CLK_PER divided by 128
        DIV128 = 0xc,
        /// CLK_PER divided by 256
        DIV256 = 0xd,
        _,
    };

    /// Resolution selection
    pub const ADC_RESSEL = enum(u2) {
        /// 12-bit mode
        @"12BIT" = 0x0,
        /// 10-bit mode
        @"10BIT" = 0x1,
        _,
    };

    /// Sampling Delay Selection
    pub const ADC_SAMPDLY = enum(u4) {
        /// Delay 0 CLK_ADC cycles
        DLY0 = 0x0,
        /// Delay 1 CLK_ADC cycles
        DLY1 = 0x1,
        /// Delay 2 CLK_ADC cycles
        DLY2 = 0x2,
        /// Delay 3 CLK_ADC cycles
        DLY3 = 0x3,
        /// Delay 4 CLK_ADC cycles
        DLY4 = 0x4,
        /// Delay 5 CLK_ADC cycles
        DLY5 = 0x5,
        /// Delay 6 CLK_ADC cycles
        DLY6 = 0x6,
        /// Delay 7 CLK_ADC cycles
        DLY7 = 0x7,
        /// Delay 8 CLK_ADC cycles
        DLY8 = 0x8,
        /// Delay 9 CLK_ADC cycles
        DLY9 = 0x9,
        /// Delay 10 CLK_ADC cycles
        DLY10 = 0xa,
        /// Delay 11 CLK_ADC cycles
        DLY11 = 0xb,
        /// Delay 12 CLK_ADC cycles
        DLY12 = 0xc,
        /// Delay 13 CLK_ADC cycles
        DLY13 = 0xd,
        /// Delay 14 CLK_ADC cycles
        DLY14 = 0xe,
        /// Delay 15 CLK_ADC cycles
        DLY15 = 0xf,
    };

    /// Accumulation Samples select
    pub const ADC_SAMPNUM = enum(u3) {
        /// No accumulation
        NONE = 0x0,
        /// 2 results accumulated
        ACC2 = 0x1,
        /// 4 results accumulated
        ACC4 = 0x2,
        /// 8 results accumulated
        ACC8 = 0x3,
        /// 16 results accumulated
        ACC16 = 0x4,
        /// 32 results accumulated
        ACC32 = 0x5,
        /// 64 results accumulated
        ACC64 = 0x6,
        /// 128 results accumulated
        ACC128 = 0x7,
    };

    /// Window Comparator Mode select
    pub const ADC_WINCM = enum(u3) {
        /// No Window Comparison
        NONE = 0x0,
        /// Below Window
        BELOW = 0x1,
        /// Above Window
        ABOVE = 0x2,
        /// Inside Window
        INSIDE = 0x3,
        /// Outside Window
        OUTSIDE = 0x4,
        _,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// ADC Enable
        ENABLE: u1,
        /// Free running mode
        FREERUN: u1,
        /// Resolution selection
        RESSEL: ADC_RESSEL,
        /// Left adjust result
        LEFTADJ: u1,
        /// Conversion mode
        CONVMODE: ADC_CONVMODE,
        reserved7: u1 = 0,
        /// Run standby mode
        RUNSTBY: u1,
    }),
    /// Control B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// Accumulation Samples
        SAMPNUM: ADC_SAMPNUM,
        padding: u5 = 0,
    }),
    /// Control C
    /// offset: 0x02
    CTRLC: mmio.Mmio(packed struct(u8) {
        /// Clock Pre-scaler
        PRESC: ADC_PRESC,
        padding: u4 = 0,
    }),
    /// Control D
    /// offset: 0x03
    CTRLD: mmio.Mmio(packed struct(u8) {
        /// Sampling Delay Selection
        SAMPDLY: ADC_SAMPDLY,
        reserved5: u1 = 0,
        /// Initial Delay Selection
        INITDLY: ADC_INITDLY,
    }),
    /// Control E
    /// offset: 0x04
    CTRLE: mmio.Mmio(packed struct(u8) {
        /// Window Comparator Mode
        WINCM: ADC_WINCM,
        padding: u5 = 0,
    }),
    /// Sample Control
    /// offset: 0x05
    SAMPCTRL: mmio.Mmio(packed struct(u8) {
        /// Sample lenght
        SAMPLEN: u8,
    }),
    /// offset: 0x06
    reserved6: [2]u8,
    /// Positive mux input
    /// offset: 0x08
    MUXPOS: mmio.Mmio(packed struct(u8) {
        /// Analog Channel Selection Bits
        MUXPOS: ADC_MUXPOS,
        padding: u1 = 0,
    }),
    /// Negative mux input
    /// offset: 0x09
    MUXNEG: mmio.Mmio(packed struct(u8) {
        /// Analog Channel Selection Bits
        MUXNEG: ADC_MUXNEG,
        padding: u1 = 0,
    }),
    /// Command
    /// offset: 0x0a
    COMMAND: mmio.Mmio(packed struct(u8) {
        /// Start Conversion
        STCONV: u1,
        /// Stop Conversion
        SPCONV: u1,
        padding: u6 = 0,
    }),
    /// Event Control
    /// offset: 0x0b
    EVCTRL: mmio.Mmio(packed struct(u8) {
        /// Start Event Input Enable
        STARTEI: u1,
        padding: u7 = 0,
    }),
    /// Interrupt Control
    /// offset: 0x0c
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Result Ready Interrupt Enable
        RESRDY: u1,
        /// Window Comparator Interrupt Enable
        WCMP: u1,
        padding: u6 = 0,
    }),
    /// Interrupt Flags
    /// offset: 0x0d
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Result Ready Flag
        RESRDY: u1,
        /// Window Comparator Flag
        WCMP: u1,
        padding: u6 = 0,
    }),
    /// Debug Control
    /// offset: 0x0e
    DBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Debug run
        DBGRUN: u1,
        padding: u7 = 0,
    }),
    /// Temporary Data
    /// offset: 0x0f
    TEMP: mmio.Mmio(packed struct(u8) {
        /// Temporary
        TEMP: u8,
    }),
    /// ADC Accumulator Result
    /// offset: 0x10
    RES: u16,
    /// Window comparator low threshold
    /// offset: 0x12
    WINLT: u16,
    /// Window comparator high threshold
    /// offset: 0x14
    WINHT: u16,
};
