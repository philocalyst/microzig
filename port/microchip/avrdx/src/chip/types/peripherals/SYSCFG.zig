const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const SYSCFG = extern struct {
    /// offset: 0x00
    reserved0: [1]u8,
    /// Revision ID
    /// offset: 0x01
    REVID: u8,
    /// offset: 0x02
    reserved2: [2]u8,
    /// OCD Message Control
    /// offset: 0x04
    OCDMCTRL: u8,
    /// OCD Message Status
    /// offset: 0x05
    OCDMSTATUS: mmio.Mmio(packed struct(u8) {
        /// OCD Message Valid
        VALID: u1,
        padding: u7 = 0,
    }),
};
