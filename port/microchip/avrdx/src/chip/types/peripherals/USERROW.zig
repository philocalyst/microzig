const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const USERROW = extern struct {
    /// User Row
    /// offset: 0x00
    USERROW: [32]u8,
};
