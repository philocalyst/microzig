const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const VREF = extern struct {
    /// Reference select
    pub const VREF_REFSEL = enum(u3) {
        /// Internal 1.024V reference
        @"1V024" = 0x0,
        /// Internal 2.048V reference
        @"2V048" = 0x1,
        /// Internal 4.096V reference
        @"4V096" = 0x2,
        /// Internal 2.500V reference
        @"2V500" = 0x3,
        /// VDD as reference
        VDD = 0x5,
        /// External reference on VREFA pin
        VREFA = 0x6,
        _,
    };

    /// ADC0 Reference
    /// offset: 0x00
    ADC0REF: mmio.Mmio(packed struct(u8) {
        /// Reference select
        REFSEL: VREF_REFSEL,
        reserved7: u4 = 0,
        /// Always on
        ALWAYSON: u1,
    }),
    /// offset: 0x01
    reserved1: [1]u8,
    /// DAC0 Reference
    /// offset: 0x02
    DAC0REF: mmio.Mmio(packed struct(u8) {
        /// Reference select
        REFSEL: VREF_REFSEL,
        reserved7: u4 = 0,
        /// Always on
        ALWAYSON: u1,
    }),
    /// offset: 0x03
    reserved3: [1]u8,
    /// AC Reference
    /// offset: 0x04
    ACREF: mmio.Mmio(packed struct(u8) {
        /// Reference select
        REFSEL: VREF_REFSEL,
        reserved7: u4 = 0,
        /// Always on
        ALWAYSON: u1,
    }),
};
