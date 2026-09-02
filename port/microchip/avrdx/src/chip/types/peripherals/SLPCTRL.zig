const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const SLPCTRL = extern struct {
    /// High Temperature Low Leakage Enable select
    pub const SLPCTRL_HTLLEN = enum(u1) {
        /// Disabled
        OFF = 0x0,
        /// Enabled
        ON = 0x1,
    };

    /// Performance Mode select
    pub const SLPCTRL_PMODE = enum(u3) {
        AUTO = 0x0,
        FULL = 0x1,
        _,
    };

    /// Sleep mode select
    pub const SLPCTRL_SMODE = enum(u2) {
        /// Idle mode
        IDLE = 0x0,
        /// Standby Mode
        STDBY = 0x1,
        /// Power-down Mode
        PDOWN = 0x2,
        _,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Sleep enable
        SEN: u1,
        /// Sleep mode
        SMODE: SLPCTRL_SMODE,
        padding: u5 = 0,
    }),
    /// Control B
    /// offset: 0x01
    VREGCTRL: mmio.Mmio(packed struct(u8) {
        /// Performance Mode
        PMODE: SLPCTRL_PMODE,
        reserved4: u1 = 0,
        /// High Temperature Low Leakage Enable
        HTLLEN: SLPCTRL_HTLLEN,
        padding: u3 = 0,
    }),
};
