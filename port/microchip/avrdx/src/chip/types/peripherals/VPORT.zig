const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const VPORT = extern struct {
    /// Data Direction
    /// offset: 0x00
    DIR: u8,
    /// Output Value
    /// offset: 0x01
    OUT: u8,
    /// Input Value
    /// offset: 0x02
    IN: u8,
    /// Interrupt Flags
    /// offset: 0x03
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Pin Interrupt Flag
        INT: u8,
    }),
};
