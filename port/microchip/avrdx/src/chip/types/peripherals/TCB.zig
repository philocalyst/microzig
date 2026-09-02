const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const TCB = extern struct {
    /// Clock Select
    pub const TCB_CLKSEL = enum(u3) {
        /// CLK_PER
        DIV1 = 0x0,
        /// CLK_PER/2
        DIV2 = 0x1,
        /// Use CLK_TCA from TCA0
        TCA0 = 0x2,
        /// Count on event edge
        EVENT = 0x7,
        _,
    };

    /// Timer Mode select
    pub const TCB_CNTMODE = enum(u3) {
        /// Periodic Interrupt
        INT = 0x0,
        /// Periodic Timeout
        TIMEOUT = 0x1,
        /// Input Capture Event
        CAPT = 0x2,
        /// Input Capture Frequency measurement
        FRQ = 0x3,
        /// Input Capture Pulse-Width measurement
        PW = 0x4,
        /// Input Capture Frequency and Pulse-Width measurement
        FRQPW = 0x5,
        /// Single Shot
        SINGLE = 0x6,
        /// 8-bit PWM
        PWM8 = 0x7,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Clock Select
        CLKSEL: TCB_CLKSEL,
        /// Synchronize Update
        SYNCUPD: u1,
        /// Cascade two timers
        CASCADE: u1,
        /// Run Standby
        RUNSTDBY: u1,
        padding: u1 = 0,
    }),
    /// Control Register B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// Timer Mode
        CNTMODE: TCB_CNTMODE,
        reserved4: u1 = 0,
        /// Pin Output Enable
        CCMPEN: u1,
        /// Pin Initial State
        CCMPINIT: u1,
        /// Asynchronous Enable
        ASYNC: u1,
        padding: u1 = 0,
    }),
    /// offset: 0x02
    reserved2: [2]u8,
    /// Event Control
    /// offset: 0x04
    EVCTRL: mmio.Mmio(packed struct(u8) {
        /// Event Input Enable
        CAPTEI: u1,
        reserved4: u3 = 0,
        /// Event Edge
        EDGE: u1,
        reserved6: u1 = 0,
        /// Input Capture Noise Cancellation Filter
        FILTER: u1,
        padding: u1 = 0,
    }),
    /// Interrupt Control
    /// offset: 0x05
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Capture or Timeout
        CAPT: u1,
        /// Overflow
        OVF: u1,
        padding: u6 = 0,
    }),
    /// Interrupt Flags
    /// offset: 0x06
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Capture or Timeout
        CAPT: u1,
        /// Overflow
        OVF: u1,
        padding: u6 = 0,
    }),
    /// Status
    /// offset: 0x07
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Run
        RUN: u1,
        padding: u7 = 0,
    }),
    /// Debug Control
    /// offset: 0x08
    DBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Debug Run
        DBGRUN: u1,
        padding: u7 = 0,
    }),
    /// Temporary Value
    /// offset: 0x09
    TEMP: u8,
    /// Count
    /// offset: 0x0a
    CNT: u16,
    /// Compare or Capture
    /// offset: 0x0c
    CCMP: u16,
};
