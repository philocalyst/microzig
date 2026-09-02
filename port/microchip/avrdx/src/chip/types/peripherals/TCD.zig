const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const TCD = extern struct {
    /// Event action select
    pub const TCD_ACTION = enum(u1) {
        /// Event trigger a fault
        FAULT = 0x0,
        /// Event trigger a fault and capture
        CAPTURE = 0x1,
    };

    /// Event config select
    pub const TCD_CFG = enum(u2) {
        /// Neither Filter nor Asynchronous Event is enabled
        NEITHER = 0x0,
        /// Input Capture Noise Cancellation Filter enabled
        FILTER = 0x1,
        /// Asynchronous Event output qualification enabled
        ASYNC = 0x2,
        _,
    };

    /// Clock select
    pub const TCD_CLKSEL = enum(u2) {
        /// Internal High-Frequency oscillator
        OSCHF = 0x0,
        /// PLL
        PLL = 0x1,
        /// External clock
        EXTCLK = 0x2,
        /// Peripheral Clock
        CLKPER = 0x3,
    };

    /// Compare C output select
    pub const TCD_CMPCSEL = enum(u1) {
        /// PWM A output
        PWMA = 0x0,
        /// PWM B output
        PWMB = 0x1,
    };

    /// Compare D output select
    pub const TCD_CMPDSEL = enum(u1) {
        /// PWM A output
        PWMA = 0x0,
        /// PWM B output
        PWMB = 0x1,
    };

    /// Counter prescaler select
    pub const TCD_CNTPRES = enum(u2) {
        /// Sync clock divided by 1
        DIV1 = 0x0,
        /// Sync clock divided by 4
        DIV4 = 0x1,
        /// Sync clock divided by 32
        DIV32 = 0x2,
        _,
    };

    /// Dither select
    pub const TCD_DITHERSEL = enum(u2) {
        /// On-time ramp B
        ONTIMEB = 0x0,
        /// On-time ramp A and B
        ONTIMEAB = 0x1,
        /// Dead-time rampB
        DEADTIMEB = 0x2,
        /// Dead-time ramp A and B
        DEADTIMEAB = 0x3,
    };

    /// Delay prescaler select
    pub const TCD_DLYPRESC = enum(u2) {
        /// No prescaling
        DIV1 = 0x0,
        /// Prescale with 2
        DIV2 = 0x1,
        /// Prescale with 4
        DIV4 = 0x2,
        /// Prescale with 8
        DIV8 = 0x3,
    };

    /// Delay select
    pub const TCD_DLYSEL = enum(u2) {
        /// No delay
        OFF = 0x0,
        /// Input blanking enabled
        INBLANK = 0x1,
        /// Event delay enabled
        EVENT = 0x2,
        _,
    };

    /// Delay trigger select
    pub const TCD_DLYTRIG = enum(u2) {
        /// Compare A set
        CMPASET = 0x0,
        /// Compare A clear
        CMPACLR = 0x1,
        /// Compare B set
        CMPBSET = 0x2,
        /// Compare B clear
        CMPBCLR = 0x3,
    };

    /// Edge select
    pub const TCD_EDGE = enum(u1) {
        /// The falling edge or low level of event generates retrigger or fault action
        FALL_LOW = 0x0,
        /// The rising edge or high level of event generates retrigger or fault action
        RISE_HIGH = 0x1,
    };

    /// Input mode select
    pub const TCD_INPUTMODE = enum(u4) {
        /// Input has no actions
        NONE = 0x0,
        /// Stop output, jump to opposite compare cycle and wait
        JMPWAIT = 0x1,
        /// Stop output, execute opposite compare cycle and wait
        EXECWAIT = 0x2,
        /// stop output, execute opposite compare cycle while fault active
        EXECFAULT = 0x3,
        /// Stop all outputs, maintain frequency
        FREQ = 0x4,
        /// Stop all outputs, execute dead time while fault active
        EXECDT = 0x5,
        /// Stop all outputs, jump to next compare cycle and wait
        WAIT = 0x6,
        /// Stop all outputs, wait for software action
        WAITSW = 0x7,
        /// Stop output on edge, jump to next compare cycle
        EDGETRIG = 0x8,
        /// Stop output on edge, maintain frequency
        EDGETRIGFREQ = 0x9,
        /// Stop output at level, maintain frequency
        LVLTRIGFREQ = 0xa,
        _,
    };

    /// Synchronization prescaler select
    pub const TCD_SYNCPRES = enum(u2) {
        /// Selected clock source divided by 1
        DIV1 = 0x0,
        /// Selected clock source divided by 2
        DIV2 = 0x1,
        /// Selected clock source divided by 4
        DIV4 = 0x2,
        /// Selected clock source divided by 8
        DIV8 = 0x3,
    };

    /// Waveform generation mode select
    pub const TCD_WGMODE = enum(u2) {
        /// One ramp mode
        ONERAMP = 0x0,
        /// Two ramp mode
        TWORAMP = 0x1,
        /// Four ramp mode
        FOURRAMP = 0x2,
        /// Dual slope mode
        DS = 0x3,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Synchronization prescaler
        SYNCPRES: TCD_SYNCPRES,
        /// Counter prescaler
        CNTPRES: TCD_CNTPRES,
        /// Clock select
        CLKSEL: TCD_CLKSEL,
        padding: u1 = 0,
    }),
    /// Control B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// Waveform generation mode
        WGMODE: TCD_WGMODE,
        padding: u6 = 0,
    }),
    /// Control C
    /// offset: 0x02
    CTRLC: mmio.Mmio(packed struct(u8) {
        /// Compare output value override
        CMPOVR: u1,
        /// Auto update
        AUPDATE: u1,
        reserved3: u1 = 0,
        /// Fifty percent waveform
        FIFTY: u1,
        reserved6: u2 = 0,
        /// Compare C output select
        CMPCSEL: TCD_CMPCSEL,
        /// Compare D output select
        CMPDSEL: TCD_CMPDSEL,
    }),
    /// Control D
    /// offset: 0x03
    CTRLD: mmio.Mmio(packed struct(u8) {
        /// Compare A value
        CMPAVAL: u4,
        /// Compare B value
        CMPBVAL: u4,
    }),
    /// Control E
    /// offset: 0x04
    CTRLE: mmio.Mmio(packed struct(u8) {
        /// Synchronize end of cycle strobe
        SYNCEOC: u1,
        /// synchronize strobe
        SYNC: u1,
        /// Restart strobe
        RESTART: u1,
        /// Software Capture A Strobe
        SCAPTUREA: u1,
        /// Software Capture B Strobe
        SCAPTUREB: u1,
        reserved7: u2 = 0,
        /// Disable at end of cycle
        DISEOC: u1,
    }),
    /// offset: 0x05
    reserved5: [3]u8,
    /// EVCTRLA
    /// offset: 0x08
    EVCTRLA: mmio.Mmio(packed struct(u8) {
        /// Trigger event enable
        TRIGEI: u1,
        reserved2: u1 = 0,
        /// Event action
        ACTION: TCD_ACTION,
        reserved4: u1 = 0,
        /// Edge select
        EDGE: TCD_EDGE,
        reserved6: u1 = 0,
        /// Event config
        CFG: TCD_CFG,
    }),
    /// EVCTRLB
    /// offset: 0x09
    EVCTRLB: mmio.Mmio(packed struct(u8) {
        /// Trigger event enable
        TRIGEI: u1,
        reserved2: u1 = 0,
        /// Event action
        ACTION: TCD_ACTION,
        reserved4: u1 = 0,
        /// Edge select
        EDGE: TCD_EDGE,
        reserved6: u1 = 0,
        /// Event config
        CFG: TCD_CFG,
    }),
    /// offset: 0x0a
    reserved10: [2]u8,
    /// Interrupt Control
    /// offset: 0x0c
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Overflow interrupt enable
        OVF: u1,
        reserved2: u1 = 0,
        /// Trigger A interrupt enable
        TRIGA: u1,
        /// Trigger B interrupt enable
        TRIGB: u1,
        padding: u4 = 0,
    }),
    /// Interrupt Flags
    /// offset: 0x0d
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Overflow interrupt enable
        OVF: u1,
        reserved2: u1 = 0,
        /// Trigger A interrupt enable
        TRIGA: u1,
        /// Trigger B interrupt enable
        TRIGB: u1,
        padding: u4 = 0,
    }),
    /// Status
    /// offset: 0x0e
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Enable ready
        ENRDY: u1,
        /// Command ready
        CMDRDY: u1,
        reserved6: u4 = 0,
        /// PWM activity on A
        PWMACTA: u1,
        /// PWM activity on B
        PWMACTB: u1,
    }),
    /// offset: 0x0f
    reserved15: [1]u8,
    /// Input Control A
    /// offset: 0x10
    INPUTCTRLA: mmio.Mmio(packed struct(u8) {
        /// Input mode
        INPUTMODE: TCD_INPUTMODE,
        padding: u4 = 0,
    }),
    /// Input Control B
    /// offset: 0x11
    INPUTCTRLB: mmio.Mmio(packed struct(u8) {
        /// Input mode
        INPUTMODE: TCD_INPUTMODE,
        padding: u4 = 0,
    }),
    /// Fault Control
    /// offset: 0x12
    FAULTCTRL: mmio.Mmio(packed struct(u8) {
        /// Compare A value
        CMPA: u1,
        /// Compare B value
        CMPB: u1,
        /// Compare C value
        CMPC: u1,
        /// Compare D vaule
        CMPD: u1,
        /// Compare A enable
        CMPAEN: u1,
        /// Compare B enable
        CMPBEN: u1,
        /// Compare C enable
        CMPCEN: u1,
        /// Compare D enable
        CMPDEN: u1,
    }),
    /// offset: 0x13
    reserved19: [1]u8,
    /// Delay Control
    /// offset: 0x14
    DLYCTRL: mmio.Mmio(packed struct(u8) {
        /// Delay select
        DLYSEL: TCD_DLYSEL,
        /// Delay trigger
        DLYTRIG: TCD_DLYTRIG,
        /// Delay prescaler
        DLYPRESC: TCD_DLYPRESC,
        padding: u2 = 0,
    }),
    /// Delay value
    /// offset: 0x15
    DLYVAL: mmio.Mmio(packed struct(u8) {
        /// Delay value
        DLYVAL: u8,
    }),
    /// offset: 0x16
    reserved22: [2]u8,
    /// Dither Control A
    /// offset: 0x18
    DITCTRL: mmio.Mmio(packed struct(u8) {
        /// Dither select
        DITHERSEL: TCD_DITHERSEL,
        padding: u6 = 0,
    }),
    /// Dither value
    /// offset: 0x19
    DITVAL: mmio.Mmio(packed struct(u8) {
        /// Dither value
        DITHER: u4,
        padding: u4 = 0,
    }),
    /// offset: 0x1a
    reserved26: [4]u8,
    /// Debug Control
    /// offset: 0x1e
    DBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Debug run
        DBGRUN: u1,
        reserved2: u1 = 0,
        /// Fault detection
        FAULTDET: u1,
        padding: u5 = 0,
    }),
    /// offset: 0x1f
    reserved31: [3]u8,
    /// Capture A
    /// offset: 0x22
    CAPTUREA: mmio.Mmio(packed struct(u16) {
        /// Capture A
        CAPTUREA: u12,
        padding: u4 = 0,
    }),
    /// Capture B
    /// offset: 0x24
    CAPTUREB: mmio.Mmio(packed struct(u16) {
        /// Capture B
        CAPTUREB: u12,
        padding: u4 = 0,
    }),
    /// offset: 0x26
    reserved38: [2]u8,
    /// Compare A Set
    /// offset: 0x28
    CMPASET: mmio.Mmio(packed struct(u16) {
        /// Compare A Set
        CMPASET: u12,
        padding: u4 = 0,
    }),
    /// Compare A Clear
    /// offset: 0x2a
    CMPACLR: mmio.Mmio(packed struct(u16) {
        /// Compare A Clear
        CMPACLR: u12,
        padding: u4 = 0,
    }),
    /// Compare B Set
    /// offset: 0x2c
    CMPBSET: mmio.Mmio(packed struct(u16) {
        /// Compare B Set
        CMPBSET: u12,
        padding: u4 = 0,
    }),
    /// Compare B Clear
    /// offset: 0x2e
    CMPBCLR: mmio.Mmio(packed struct(u16) {
        /// Compare B Clear
        COMPBCLR: u12,
        padding: u4 = 0,
    }),
};
