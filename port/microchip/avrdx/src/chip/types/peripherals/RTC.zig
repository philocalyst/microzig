const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const RTC = extern struct {
    /// Clock Select
    pub const RTC_CLKSEL = enum(u2) {
        /// 32.768 kHz from OSC32K
        OSC32K = 0x0,
        /// 1.024 kHz from OSC32K
        OSC1K = 0x1,
        /// 32.768 kHz from XOSC32K
        XTAL32K = 0x2,
        /// External Clock
        EXTCLK = 0x3,
    };

    /// Period select
    pub const RTC_PERIOD = enum(u4) {
        /// Off
        OFF = 0x0,
        /// RTC Clock Cycles 4
        CYC4 = 0x1,
        /// RTC Clock Cycles 8
        CYC8 = 0x2,
        /// RTC Clock Cycles 16
        CYC16 = 0x3,
        /// RTC Clock Cycles 32
        CYC32 = 0x4,
        /// RTC Clock Cycles 64
        CYC64 = 0x5,
        /// RTC Clock Cycles 128
        CYC128 = 0x6,
        /// RTC Clock Cycles 256
        CYC256 = 0x7,
        /// RTC Clock Cycles 512
        CYC512 = 0x8,
        /// RTC Clock Cycles 1024
        CYC1024 = 0x9,
        /// RTC Clock Cycles 2048
        CYC2048 = 0xa,
        /// RTC Clock Cycles 4096
        CYC4096 = 0xb,
        /// RTC Clock Cycles 8192
        CYC8192 = 0xc,
        /// RTC Clock Cycles 16384
        CYC16384 = 0xd,
        /// RTC Clock Cycles 32768
        CYC32768 = 0xe,
        _,
    };

    /// Prescaling Factor select
    pub const RTC_PRESCALER = enum(u4) {
        /// RTC Clock / 1
        DIV1 = 0x0,
        /// RTC Clock / 2
        DIV2 = 0x1,
        /// RTC Clock / 4
        DIV4 = 0x2,
        /// RTC Clock / 8
        DIV8 = 0x3,
        /// RTC Clock / 16
        DIV16 = 0x4,
        /// RTC Clock / 32
        DIV32 = 0x5,
        /// RTC Clock / 64
        DIV64 = 0x6,
        /// RTC Clock / 128
        DIV128 = 0x7,
        /// RTC Clock / 256
        DIV256 = 0x8,
        /// RTC Clock / 512
        DIV512 = 0x9,
        /// RTC Clock / 1024
        DIV1024 = 0xa,
        /// RTC Clock / 2048
        DIV2048 = 0xb,
        /// RTC Clock / 4096
        DIV4096 = 0xc,
        /// RTC Clock / 8192
        DIV8192 = 0xd,
        /// RTC Clock / 16384
        DIV16384 = 0xe,
        /// RTC Clock / 32768
        DIV32768 = 0xf,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        RTCEN: u1,
        reserved2: u1 = 0,
        /// Correction enable
        CORREN: u1,
        /// Prescaling Factor
        PRESCALER: RTC_PRESCALER,
        /// Run In Standby
        RUNSTDBY: u1,
    }),
    /// Status
    /// offset: 0x01
    STATUS: mmio.Mmio(packed struct(u8) {
        /// CTRLA Synchronization Busy Flag
        CTRLABUSY: u1,
        /// Count Synchronization Busy Flag
        CNTBUSY: u1,
        /// Period Synchronization Busy Flag
        PERBUSY: u1,
        /// Comparator Synchronization Busy Flag
        CMPBUSY: u1,
        padding: u4 = 0,
    }),
    /// Interrupt Control
    /// offset: 0x02
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Overflow Interrupt enable
        OVF: u1,
        /// Compare Match Interrupt enable
        CMP: u1,
        padding: u6 = 0,
    }),
    /// Interrupt Flags
    /// offset: 0x03
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Overflow Interrupt Flag
        OVF: u1,
        /// Compare Match Interrupt
        CMP: u1,
        padding: u6 = 0,
    }),
    /// Temporary
    /// offset: 0x04
    TEMP: u8,
    /// Debug control
    /// offset: 0x05
    DBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Run in debug
        DBGRUN: u1,
        padding: u7 = 0,
    }),
    /// Calibration
    /// offset: 0x06
    CALIB: mmio.Mmio(packed struct(u8) {
        /// Error Correction Value
        ERROR: u7,
        /// Error Correction Sign Bit
        SIGN: u1,
    }),
    /// Clock Select
    /// offset: 0x07
    CLKSEL: mmio.Mmio(packed struct(u8) {
        /// Clock Select
        CLKSEL: RTC_CLKSEL,
        padding: u6 = 0,
    }),
    /// Counter
    /// offset: 0x08
    CNT: u16,
    /// Period
    /// offset: 0x0a
    PER: u16,
    /// Compare
    /// offset: 0x0c
    CMP: u16,
    /// offset: 0x0e
    reserved14: [2]u8,
    /// PIT Control A
    /// offset: 0x10
    PITCTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        PITEN: u1,
        reserved3: u2 = 0,
        /// Period
        PERIOD: RTC_PERIOD,
        padding: u1 = 0,
    }),
    /// PIT Status
    /// offset: 0x11
    PITSTATUS: mmio.Mmio(packed struct(u8) {
        /// CTRLA Synchronization Busy Flag
        CTRLBUSY: u1,
        padding: u7 = 0,
    }),
    /// PIT Interrupt Control
    /// offset: 0x12
    PITINTCTRL: mmio.Mmio(packed struct(u8) {
        /// Periodic Interrupt
        PI: u1,
        padding: u7 = 0,
    }),
    /// PIT Interrupt Flags
    /// offset: 0x13
    PITINTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Periodic Interrupt
        PI: u1,
        padding: u7 = 0,
    }),
    /// offset: 0x14
    reserved20: [1]u8,
    /// PIT Debug control
    /// offset: 0x15
    PITDBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Run in debug
        DBGRUN: u1,
        padding: u7 = 0,
    }),
};
