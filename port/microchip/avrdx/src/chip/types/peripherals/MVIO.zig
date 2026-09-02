const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const MVIO = extern struct {
    /// Interrupt Control
    /// offset: 0x00
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// VDDIO2 Interrupt Enable
        VDDIO2IE: u1,
        padding: u7 = 0,
    }),
    /// Interrupt Flags
    /// offset: 0x01
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// VDDIO2 Interrupt Flag
        VDDIO2IF: u1,
        padding: u7 = 0,
    }),
    /// Status
    /// offset: 0x02
    STATUS: mmio.Mmio(packed struct(u8) {
        /// VDDIO2 Status
        VDDIO2S: u1,
        padding: u7 = 0,
    }),
};
