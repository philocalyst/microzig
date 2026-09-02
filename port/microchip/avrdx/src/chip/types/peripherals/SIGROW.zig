const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const SIGROW = extern struct {
    /// Device ID Byte 0
    /// offset: 0x00
    DEVICEID0: u8,
    /// Device ID Byte 1
    /// offset: 0x01
    DEVICEID1: u8,
    /// Device ID Byte 2
    /// offset: 0x02
    DEVICEID2: u8,
    /// offset: 0x03
    reserved3: [1]u8,
    /// Temperature Calibration 0
    /// offset: 0x04
    TEMPSENSE0: mmio.Mmio(packed struct(u16) {
        /// Temperature Calibration 0
        TEMPSENSE0: u16,
    }),
    /// Temperature Calibration 1
    /// offset: 0x06
    TEMPSENSE1: mmio.Mmio(packed struct(u16) {
        /// Temperature Calibration 1
        TEMPSENSE1: u16,
    }),
    /// offset: 0x08
    reserved8: [8]u8,
    /// LOTNUM0
    /// offset: 0x10
    SERNUM0: u8,
    /// LOTNUM1
    /// offset: 0x11
    SERNUM1: u8,
    /// LOTNUM2
    /// offset: 0x12
    SERNUM2: u8,
    /// LOTNUM3
    /// offset: 0x13
    SERNUM3: u8,
    /// LOTNUM4
    /// offset: 0x14
    SERNUM4: u8,
    /// LOTNUM5
    /// offset: 0x15
    SERNUM5: u8,
    /// RANDOM
    /// offset: 0x16
    SERNUM6: u8,
    /// SCRIBE
    /// offset: 0x17
    SERNUM7: u8,
    /// XPOS0
    /// offset: 0x18
    SERNUM8: u8,
    /// XPOS1
    /// offset: 0x19
    SERNUM9: u8,
    /// YPOS0
    /// offset: 0x1a
    SERNUM10: u8,
    /// YPOS1
    /// offset: 0x1b
    SERNUM11: u8,
    /// RES0
    /// offset: 0x1c
    SERNUM12: u8,
    /// RES1
    /// offset: 0x1d
    SERNUM13: u8,
    /// RES2
    /// offset: 0x1e
    SERNUM14: u8,
    /// RES3
    /// offset: 0x1f
    SERNUM15: u8,
};
