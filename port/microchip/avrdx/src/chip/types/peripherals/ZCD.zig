const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const ZCD = extern struct {
    /// Interrupt Mode select
    pub const ZCD_INTMODE = enum(u2) {
        /// No interrupt
        NONE = 0x0,
        /// Interrupt on rising input signal
        RISING = 0x1,
        /// Interrupt on falling input signal
        FALLING = 0x2,
        /// Interrupt on both rising and falling input signal
        BOTH = 0x3,
    };

    /// ZCD State select
    pub const ZCD_STATE = enum(u1) {
        /// Output is 0
        LOW = 0x0,
        /// Output is 1
        HIGH = 0x1,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        reserved3: u2 = 0,
        /// Invert signal from pin
        INVERT: u1,
        reserved6: u2 = 0,
        /// Output Pad Enable
        OUTEN: u1,
        /// Run in Standby Mode
        RUNSTDBY: u1,
    }),
    /// offset: 0x01
    reserved1: [1]u8,
    /// Interrupt Control
    /// offset: 0x02
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Interrupt Mode
        INTMODE: ZCD_INTMODE,
        padding: u6 = 0,
    }),
    /// Status
    /// offset: 0x03
    STATUS: mmio.Mmio(packed struct(u8) {
        /// ZCD Interrupt Flag
        CROSSIF: u1,
        reserved4: u3 = 0,
        /// ZCD State
        STATE: ZCD_STATE,
        padding: u3 = 0,
    }),
};
