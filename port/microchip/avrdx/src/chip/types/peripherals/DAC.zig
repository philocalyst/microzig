const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const DAC = extern struct {
    /// Control Register A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// DAC Enable
        ENABLE: u1,
        reserved6: u5 = 0,
        /// Output Buffer Enable
        OUTEN: u1,
        /// Run in Standby Mode
        RUNSTDBY: u1,
    }),
    /// offset: 0x01
    reserved1: [1]u8,
    /// DATA Register
    /// offset: 0x02
    DATA: mmio.Mmio(packed struct(u16) {
        reserved6: u6 = 0,
        /// Data
        DATA: u10,
    }),
};
