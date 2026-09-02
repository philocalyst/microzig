const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const CRCSCAN = extern struct {
    /// CRC Source select
    pub const CRCSCAN_SRC = enum(u2) {
        /// CRC on entire flash
        FLASH = 0x0,
        /// CRC on boot and appl section of flash
        BOOTAPP = 0x1,
        /// CRC on boot section of flash
        BOOT = 0x2,
        _,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable CRC scan
        ENABLE: u1,
        /// Enable NMI Trigger
        NMIEN: u1,
        reserved7: u5 = 0,
        /// Reset CRC scan
        RESET: u1,
    }),
    /// Control B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// CRC Source
        SRC: CRCSCAN_SRC,
        padding: u6 = 0,
    }),
    /// Status
    /// offset: 0x02
    STATUS: mmio.Mmio(packed struct(u8) {
        /// CRC Busy
        BUSY: u1,
        /// CRC Ok
        OK: u1,
        padding: u6 = 0,
    }),
};
