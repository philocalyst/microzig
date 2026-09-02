const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const NVMCTRL = extern struct {
    /// Command select
    pub const NVMCTRL_CMD = enum(u7) {
        /// No Command
        NONE = 0x0,
        /// No Operation
        NOOP = 0x1,
        /// Flash Write
        FLWR = 0x2,
        /// Flash Page Erase
        FLPER = 0x8,
        /// Flash Multi-Page Erase 2 pages
        FLMPER2 = 0x9,
        /// Flash Multi-Page Erase 4 pages
        FLMPER4 = 0xa,
        /// Flash Multi-Page Erase 8 pages
        FLMPER8 = 0xb,
        /// Flash Multi-Page Erase 16 pages
        FLMPER16 = 0xc,
        /// Flash Multi-Page Erase 32 pages
        FLMPER32 = 0xd,
        /// EEPROM Write
        EEWR = 0x12,
        /// EEPROM Erase and Write
        EEERWR = 0x13,
        /// EEPROM Byte Erase
        EEBER = 0x18,
        /// EEPROM Multi-Byte Erase 2 bytes
        EEMBER2 = 0x19,
        /// EEPROM Multi-Byte Erase 4 bytes
        EEMBER4 = 0x1a,
        /// EEPROM Multi-Byte Erase 8 bytes
        EEMBER8 = 0x1b,
        /// EEPROM Multi-Byte Erase 16 bytes
        EEMBER16 = 0x1c,
        /// EEPROM Multi-Byte Erase 32 bytes
        EEMBER32 = 0x1d,
        /// Chip Erase Command
        CHER = 0x20,
        /// EEPROM Erase Command
        EECHER = 0x30,
        _,
    };

    /// Write error select
    pub const NVMCTRL_ERROR = enum(u3) {
        /// No Error
        NOERROR = 0x0,
        /// Write command not selected
        ILLEGALCMD = 0x1,
        /// Write to section not allowed
        ILLEGALSADDR = 0x2,
        /// Selecting new write command while write command already seleted
        DOUBLESELECT = 0x3,
        /// Starting a new programming operation before previous is completed
        ONGOINGPROG = 0x4,
        _,
    };

    /// Flash Mapping in Data space select
    pub const NVMCTRL_FLMAP = enum(u2) {
        /// Flash section 0
        SECTION0 = 0x0,
        /// Flash section 1
        SECTION1 = 0x1,
        /// Flash section 2
        SECTION2 = 0x2,
        /// Flash section 3
        SECTION3 = 0x3,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Command
        CMD: NVMCTRL_CMD,
        padding: u1 = 0,
    }),
    /// Control B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// Application Code Write Protect
        APPCODEWP: u1,
        /// Boot Read Protect
        BOOTRP: u1,
        /// Application Data Write Protect
        APPDATAWP: u1,
        reserved4: u1 = 0,
        /// Flash Mapping in Data space
        FLMAP: NVMCTRL_FLMAP,
        reserved7: u1 = 0,
        /// Flash Mapping Lock
        FLMAPLOCK: u1,
    }),
    /// Status
    /// offset: 0x02
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Flash busy
        FBUSY: u1,
        /// EEPROM busy
        EEBUSY: u1,
        reserved4: u2 = 0,
        /// Write error
        ERROR: NVMCTRL_ERROR,
        padding: u1 = 0,
    }),
    /// Interrupt Control
    /// offset: 0x03
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// EEPROM Ready
        EEREADY: u1,
        padding: u7 = 0,
    }),
    /// Interrupt Flags
    /// offset: 0x04
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// EEPROM Ready
        EEREADY: u1,
        padding: u7 = 0,
    }),
    /// offset: 0x05
    reserved5: [1]u8,
    /// Data
    /// offset: 0x06
    DATA: u16,
    /// Address
    /// offset: 0x08
    ADDR: u32,
};
