const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const AC = extern struct {
    /// Hysteresis Mode select
    pub const AC_HYSMODE = enum(u2) {
        /// No hysteresis
        NONE = 0x0,
        /// Small hysteresis
        SMALL = 0x1,
        /// Medium hysteresis
        MEDIUM = 0x2,
        /// Large hysteresis
        LARGE = 0x3,
    };

    /// AC Output Initial Value select
    pub const AC_INITVAL = enum(u1) {
        /// Output initialized to 0
        LOW = 0x0,
        /// Output initialized to 1
        HIGH = 0x1,
    };

    /// Negative Input MUX Selection
    pub const AC_MUXNEG = enum(u3) {
        /// Negative Pin 0
        AINN0 = 0x0,
        /// Negative Pin 2
        AINN2 = 0x2,
        /// Negative Pin 3
        AINN3 = 0x3,
        /// DAC Reference
        DACREF = 0x4,
        _,
    };

    /// Positive Input MUX Selection
    pub const AC_MUXPOS = enum(u3) {
        /// Positive Pin 0
        AINP0 = 0x0,
        /// Positive Pin 3
        AINP3 = 0x3,
        /// Positive Pin 4
        AINP4 = 0x4,
        _,
    };

    /// Interrupt Mode select
    pub const AC_NORMAL_INTMODE = enum(u2) {
        /// Positive and negative inputs crosses
        BOTHEDGE = 0x0,
        /// Positive input goes below negative input
        NEGEDGE = 0x2,
        /// Positive input goes above negative input
        POSEDGE = 0x3,
        _,
    };

    /// Power profile select
    pub const AC_POWER = enum(u2) {
        /// Power profile 0, Shortest response time, highest consumption
        PROFILE0 = 0x0,
        /// Power profile 1
        PROFILE1 = 0x1,
        /// Power profile 2
        PROFILE2 = 0x2,
        /// Power profile 3
        PROFILE3 = 0x3,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Hysteresis Mode
        HYSMODE: AC_HYSMODE,
        /// Power profile
        POWER: AC_POWER,
        reserved6: u1 = 0,
        /// Output Pad Enable
        OUTEN: u1,
        /// Run in Standby Mode
        RUNSTDBY: u1,
    }),
    /// offset: 0x01
    reserved1: [1]u8,
    /// Mux Control A
    /// offset: 0x02
    MUXCTRL: mmio.Mmio(packed struct(u8) {
        /// Negative Input MUX Selection
        MUXNEG: AC_MUXNEG,
        /// Positive Input MUX Selection
        MUXPOS: AC_MUXPOS,
        /// AC Output Initial Value
        INITVAL: AC_INITVAL,
        /// Invert AC Output
        INVERT: u1,
    }),
    /// offset: 0x03
    reserved3: [2]u8,
    /// DAC Voltage Reference
    /// offset: 0x05
    DACREF: mmio.Mmio(packed struct(u8) {
        /// DACREF
        DACREF: u8,
    }),
    /// Interrupt Control
    /// offset: 0x06
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Interrupt Enable
        CMP: u1,
        reserved4: u3 = 0,
        /// Interrupt Mode
        INTMODE: AC_NORMAL_INTMODE,
        padding: u2 = 0,
    }),
    /// Status
    /// offset: 0x07
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Analog Comparator Interrupt Flag
        CMPIF: u1,
        reserved4: u3 = 0,
        /// Analog Comparator State
        CMPSTATE: u1,
        padding: u3 = 0,
    }),
};
