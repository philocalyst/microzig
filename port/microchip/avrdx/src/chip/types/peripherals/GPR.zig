const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const GPR = extern struct {
    /// General Purpose Register 0
    /// offset: 0x00
    GPR0: u8,
    /// General Purpose Register 1
    /// offset: 0x01
    GPR1: u8,
    /// General Purpose Register 2
    /// offset: 0x02
    GPR2: u8,
    /// General Purpose Register 3
    /// offset: 0x03
    GPR3: u8,
};
