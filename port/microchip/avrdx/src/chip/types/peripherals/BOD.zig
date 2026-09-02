const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const BOD = extern struct {
    /// Operation in active mode select
    pub const BOD_ACTIVE = enum(u2) {
        /// Disabled
        DIS = 0x0,
        /// Enabled
        ENABLED = 0x1,
        /// Sampled
        SAMPLED = 0x2,
        /// Enabled with wake-up halted until BOD is ready
        ENWAKE = 0x3,
    };

    /// Bod level select
    pub const BOD_LVL = enum(u3) {
        /// 1.9 V
        BODLEVEL0 = 0x0,
        /// 2.45 V
        BODLEVEL1 = 0x1,
        /// 2.7 V
        BODLEVEL2 = 0x2,
        /// 2.85 V
        BODLEVEL3 = 0x3,
        _,
    };

    /// Sample frequency select
    pub const BOD_SAMPFREQ = enum(u1) {
        /// 128Hz sampling frequency
        @"128HZ" = 0x0,
        /// 32Hz sampling frequency
        @"32HZ" = 0x1,
    };

    /// Operation in sleep mode select
    pub const BOD_SLEEP = enum(u2) {
        /// Disabled
        DIS = 0x0,
        /// Enabled
        ENABLED = 0x1,
        /// Sampled
        SAMPLED = 0x2,
        _,
    };

    /// Configuration select
    pub const BOD_VLMCFG = enum(u2) {
        /// VDD falls below VLM threshold
        FALLING = 0x0,
        /// VDD rises above VLM threshold
        RISING = 0x1,
        /// VDD crosses VLM threshold
        BOTH = 0x2,
        _,
    };

    /// voltage level monitor level select
    pub const BOD_VLMLVL = enum(u2) {
        /// VLM Disabled
        OFF = 0x0,
        /// VLM threshold 5% above BOD level
        @"5ABOVE" = 0x1,
        /// VLM threshold 15% above BOD level
        @"15ABOVE" = 0x2,
        /// VLM threshold 25% above BOD level
        @"25ABOVE" = 0x3,
    };

    /// Voltage level monitor status select
    pub const BOD_VLMS = enum(u1) {
        /// The voltage is above the VLM threshold level
        ABOVE = 0x0,
        /// The voltage is below the VLM threshold level
        BELOW = 0x1,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Operation in sleep mode
        SLEEP: BOD_SLEEP,
        /// Operation in active mode
        ACTIVE: BOD_ACTIVE,
        /// Sample frequency
        SAMPFREQ: BOD_SAMPFREQ,
        padding: u3 = 0,
    }),
    /// Control B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// Bod level
        LVL: BOD_LVL,
        padding: u5 = 0,
    }),
    /// offset: 0x02
    reserved2: [6]u8,
    /// Voltage level monitor Control
    /// offset: 0x08
    VLMCTRLA: mmio.Mmio(packed struct(u8) {
        /// voltage level monitor level
        VLMLVL: BOD_VLMLVL,
        padding: u6 = 0,
    }),
    /// Voltage level monitor interrupt Control
    /// offset: 0x09
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// voltage level monitor interrrupt enable
        VLMIE: u1,
        /// Configuration
        VLMCFG: BOD_VLMCFG,
        padding: u5 = 0,
    }),
    /// Voltage level monitor interrupt Flags
    /// offset: 0x0a
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Voltage level monitor interrupt flag
        VLMIF: u1,
        padding: u7 = 0,
    }),
    /// Voltage level monitor status
    /// offset: 0x0b
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Voltage level monitor status
        VLMS: BOD_VLMS,
        padding: u7 = 0,
    }),
};
