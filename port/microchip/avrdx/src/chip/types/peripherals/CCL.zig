const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const CCL = extern struct {
    /// Clock Source Selection
    pub const CCL_CLKSRC = enum(u3) {
        /// Peripheral Clock
        CLKPER = 0x0,
        /// Selection by INSEL2
        IN2 = 0x1,
        /// Internal High-Frequency Oscillator
        OSCHF = 0x4,
        /// 32.768 kHz oscillator
        OSC32K = 0x5,
        /// 32.768 kHz oscillator divided by 32
        OSC1K = 0x6,
        _,
    };

    /// Edge Detection Enable select
    pub const CCL_EDGEDET = enum(u1) {
        /// Edge detector is disabled
        DIS = 0x0,
        /// Edge detector is enabled
        EN = 0x1,
    };

    /// Filter Selection
    pub const CCL_FILTSEL = enum(u2) {
        /// Filter disabled
        DISABLE = 0x0,
        /// Synchronizer enabled
        SYNCH = 0x1,
        /// Filter enabled
        FILTER = 0x2,
        _,
    };

    /// LUT Input 0 Source Selection
    pub const CCL_INSEL0 = enum(u4) {
        /// Masked input
        MASK = 0x0,
        /// Feedback input source
        FEEDBACK = 0x1,
        /// Linked LUT input source
        LINK = 0x2,
        /// Event input source A
        EVENTA = 0x3,
        /// Event input source B
        EVENTB = 0x4,
        /// IO pin LUTn-IN0 input source
        IN0 = 0x5,
        /// AC0 OUT input source
        AC0 = 0x6,
        /// ZCD3 OUT input source
        ZCD3 = 0x7,
        /// USART0 TXD input source
        USART0 = 0x8,
        /// SPI0 MOSI input source
        SPI0 = 0x9,
        /// TCA0 WO0 input source
        TCA0 = 0xa,
        /// TCB0 WO input source
        TCB0 = 0xb,
        /// TCD0 WOA input source
        TCD0 = 0xc,
        _,
    };

    /// LUT Input 1 Source Selection
    pub const CCL_INSEL1 = enum(u4) {
        /// Masked input
        MASK = 0x0,
        /// Feedback input source
        FEEDBACK = 0x1,
        /// Linked LUT input source
        LINK = 0x2,
        /// Event input source A
        EVENTA = 0x3,
        /// Event input source B
        EVENTB = 0x4,
        /// IO pin LUTn-IN1 input source
        IN1 = 0x5,
        /// AC0 OUT input source
        AC0 = 0x6,
        /// ZCD3 OUT input source
        ZCD3 = 0x7,
        /// USART1 TXD input source
        USART1 = 0x8,
        /// SPI0 MOSI input source
        SPI0 = 0x9,
        /// TCA0 WO1 input source
        TCA0 = 0xa,
        /// TCB1 WO input source
        TCB1 = 0xb,
        /// TCD0 WOB input source
        TCD0 = 0xc,
        _,
    };

    /// LUT Input 2 Source Selection
    pub const CCL_INSEL2 = enum(u4) {
        /// Masked input
        MASK = 0x0,
        /// Feedback input source
        FEEDBACK = 0x1,
        /// Linked LUT input source
        LINK = 0x2,
        /// Event input source A
        EVENTA = 0x3,
        /// Event input source B
        EVENTB = 0x4,
        /// IO pin LUTn-IN2 input source
        IN2 = 0x5,
        /// AC0 OUT input source
        AC0 = 0x6,
        /// ZCD3 OUT input source
        ZCD3 = 0x7,
        /// USART1 TXD input source
        USART1 = 0x8,
        /// SPI0 SCK input source
        SPI0 = 0x9,
        /// TCA0 WO2 input source
        TCA0 = 0xa,
        /// TCB2 WO input source
        TCB2 = 0xb,
        /// TCD0 WOC input source
        TCD0 = 0xc,
        _,
    };

    /// Interrupt Mode for LUT0 select
    pub const CCL_INTMODE0 = enum(u2) {
        /// Interrupt disabled
        INTDISABLE = 0x0,
        /// Sense rising edge
        RISING = 0x1,
        /// Sense falling edge
        FALLING = 0x2,
        /// Sense both edges
        BOTH = 0x3,
    };

    /// Interrupt Mode for LUT1 select
    pub const CCL_INTMODE1 = enum(u2) {
        /// Interrupt disabled
        INTDISABLE = 0x0,
        /// Sense rising edge
        RISING = 0x1,
        /// Sense falling edge
        FALLING = 0x2,
        /// Sense both edges
        BOTH = 0x3,
    };

    /// Interrupt Mode for LUT2 select
    pub const CCL_INTMODE2 = enum(u2) {
        /// Interrupt disabled
        INTDISABLE = 0x0,
        /// Sense rising edge
        RISING = 0x1,
        /// Sense falling edge
        FALLING = 0x2,
        /// Sense both edges
        BOTH = 0x3,
    };

    /// Interrupt Mode for LUT3 select
    pub const CCL_INTMODE3 = enum(u2) {
        /// Interrupt disabled
        INTDISABLE = 0x0,
        /// Sense rising edge
        RISING = 0x1,
        /// Sense falling edge
        FALLING = 0x2,
        /// Sense both edges
        BOTH = 0x3,
    };

    /// Sequential Selection
    pub const CCL_SEQSEL = enum(u4) {
        /// Sequential logic disabled
        DISABLE = 0x0,
        /// D FlipFlop
        DFF = 0x1,
        /// JK FlipFlop
        JK = 0x2,
        /// D Latch
        LATCH = 0x3,
        /// RS Latch
        RS = 0x4,
        _,
    };

    /// Control Register A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        reserved6: u5 = 0,
        /// Run in Standby
        RUNSTDBY: u1,
        padding: u1 = 0,
    }),
    /// Sequential Control 0
    /// offset: 0x01
    SEQCTRL0: mmio.Mmio(packed struct(u8) {
        /// Sequential Selection
        SEQSEL: CCL_SEQSEL,
        padding: u4 = 0,
    }),
    /// Sequential Control 1
    /// offset: 0x02
    SEQCTRL1: mmio.Mmio(packed struct(u8) {
        /// Sequential Selection
        SEQSEL: CCL_SEQSEL,
        padding: u4 = 0,
    }),
    /// offset: 0x03
    reserved3: [2]u8,
    /// Interrupt Control 0
    /// offset: 0x05
    INTCTRL0: mmio.Mmio(packed struct(u8) {
        /// Interrupt Mode for LUT0
        INTMODE0: CCL_INTMODE0,
        /// Interrupt Mode for LUT1
        INTMODE1: CCL_INTMODE1,
        /// Interrupt Mode for LUT2
        INTMODE2: CCL_INTMODE2,
        /// Interrupt Mode for LUT3
        INTMODE3: CCL_INTMODE3,
    }),
    /// offset: 0x06
    reserved6: [1]u8,
    /// Interrupt Flags
    /// offset: 0x07
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Interrupt Flag
        INT: u4,
        padding: u4 = 0,
    }),
    /// LUT 0 Control A
    /// offset: 0x08
    LUT0CTRLA: mmio.Mmio(packed struct(u8) {
        /// LUT Enable
        ENABLE: u1,
        /// Clock Source Selection
        CLKSRC: CCL_CLKSRC,
        /// Filter Selection
        FILTSEL: CCL_FILTSEL,
        /// Output Enable
        OUTEN: u1,
        /// Edge Detection Enable
        EDGEDET: CCL_EDGEDET,
    }),
    /// LUT 0 Control B
    /// offset: 0x09
    LUT0CTRLB: mmio.Mmio(packed struct(u8) {
        /// LUT Input 0 Source Selection
        INSEL0: CCL_INSEL0,
        /// LUT Input 1 Source Selection
        INSEL1: CCL_INSEL1,
    }),
    /// LUT 0 Control C
    /// offset: 0x0a
    LUT0CTRLC: mmio.Mmio(packed struct(u8) {
        /// LUT Input 2 Source Selection
        INSEL2: CCL_INSEL2,
        padding: u4 = 0,
    }),
    /// Truth 0
    /// offset: 0x0b
    TRUTH0: mmio.Mmio(packed struct(u8) {
        /// Truth Table
        TRUTH: u8,
    }),
    /// LUT 1 Control A
    /// offset: 0x0c
    LUT1CTRLA: mmio.Mmio(packed struct(u8) {
        /// LUT Enable
        ENABLE: u1,
        /// Clock Source Selection
        CLKSRC: CCL_CLKSRC,
        /// Filter Selection
        FILTSEL: CCL_FILTSEL,
        /// Output Enable
        OUTEN: u1,
        /// Edge Detection Enable
        EDGEDET: CCL_EDGEDET,
    }),
    /// LUT 1 Control B
    /// offset: 0x0d
    LUT1CTRLB: mmio.Mmio(packed struct(u8) {
        /// LUT Input 0 Source Selection
        INSEL0: CCL_INSEL0,
        /// LUT Input 1 Source Selection
        INSEL1: CCL_INSEL1,
    }),
    /// LUT 1 Control C
    /// offset: 0x0e
    LUT1CTRLC: mmio.Mmio(packed struct(u8) {
        /// LUT Input 2 Source Selection
        INSEL2: CCL_INSEL2,
        padding: u4 = 0,
    }),
    /// Truth 1
    /// offset: 0x0f
    TRUTH1: mmio.Mmio(packed struct(u8) {
        /// Truth Table
        TRUTH: u8,
    }),
    /// LUT 2 Control A
    /// offset: 0x10
    LUT2CTRLA: mmio.Mmio(packed struct(u8) {
        /// LUT Enable
        ENABLE: u1,
        /// Clock Source Selection
        CLKSRC: CCL_CLKSRC,
        /// Filter Selection
        FILTSEL: CCL_FILTSEL,
        /// Output Enable
        OUTEN: u1,
        /// Edge Detection Enable
        EDGEDET: CCL_EDGEDET,
    }),
    /// LUT 2 Control B
    /// offset: 0x11
    LUT2CTRLB: mmio.Mmio(packed struct(u8) {
        /// LUT Input 0 Source Selection
        INSEL0: CCL_INSEL0,
        /// LUT Input 1 Source Selection
        INSEL1: CCL_INSEL1,
    }),
    /// LUT 2 Control C
    /// offset: 0x12
    LUT2CTRLC: mmio.Mmio(packed struct(u8) {
        /// LUT Input 2 Source Selection
        INSEL2: CCL_INSEL2,
        padding: u4 = 0,
    }),
    /// Truth 2
    /// offset: 0x13
    TRUTH2: mmio.Mmio(packed struct(u8) {
        /// Truth Table
        TRUTH: u8,
    }),
    /// LUT 3 Control A
    /// offset: 0x14
    LUT3CTRLA: mmio.Mmio(packed struct(u8) {
        /// LUT Enable
        ENABLE: u1,
        /// Clock Source Selection
        CLKSRC: CCL_CLKSRC,
        /// Filter Selection
        FILTSEL: CCL_FILTSEL,
        /// Output Enable
        OUTEN: u1,
        /// Edge Detection Enable
        EDGEDET: CCL_EDGEDET,
    }),
    /// LUT 3 Control B
    /// offset: 0x15
    LUT3CTRLB: mmio.Mmio(packed struct(u8) {
        /// LUT Input 0 Source Selection
        INSEL0: CCL_INSEL0,
        /// LUT Input 1 Source Selection
        INSEL1: CCL_INSEL1,
    }),
    /// LUT 3 Control C
    /// offset: 0x16
    LUT3CTRLC: mmio.Mmio(packed struct(u8) {
        /// LUT Input 2 Source Selection
        INSEL2: CCL_INSEL2,
        padding: u4 = 0,
    }),
    /// Truth 3
    /// offset: 0x17
    TRUTH3: mmio.Mmio(packed struct(u8) {
        /// Truth Table
        TRUTH: u8,
    }),
};
