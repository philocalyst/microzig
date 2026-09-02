const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const RSTCTRL = extern struct {
    /// Reset Flags
    /// offset: 0x00
    RSTFR: mmio.Mmio(packed struct(u8) {
        /// Power on Reset flag
        PORF: u1,
        /// Brown out detector Reset flag
        BORF: u1,
        /// External Reset flag
        EXTRF: u1,
        /// Watch dog Reset flag
        WDRF: u1,
        /// Software Reset flag
        SWRF: u1,
        /// UPDI Reset flag
        UPDIRF: u1,
        padding: u2 = 0,
    }),
    /// Software Reset
    /// offset: 0x01
    SWRR: mmio.Mmio(packed struct(u8) {
        /// Software reset enable
        SWRST: u1,
        padding: u7 = 0,
    }),
};
