//! Device identity: signature row, fuses, general purpose registers and the
//! system configuration block.
//!
//! DS40002413 section 9 "Peripherals and Architecture", page 63, and
//! section 11.3.1.3 "Signature Row", page 74.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=74

const std = @import("std");
const regs = @import("registers.zig");

/// Static facts about this part, from the AVR32DD20 ATDF.
pub const info = struct {
    pub const name = "AVR32DD20";
    pub const flash_size = regs.memory.flash_size;
    pub const flash_page_size = regs.memory.flash_page_size;
    pub const sram_size = regs.memory.sram_size;
    pub const eeprom_size = regs.memory.eeprom_size;
    pub const user_row_size = regs.memory.user_row_size;
    /// Maximum rated CPU frequency, from the ATDF variant `speedmax`.
    pub const max_frequency_hz = 32_000_000;
    pub const vcc_min_mv = 1800;
    pub const vcc_max_mv = 5500;
    /// The 20-pin package bonds 17 I/O pads: PA0-PA7, PC1-PC3, PD4-PD7,
    /// PF6-PF7.
    pub const io_pin_count = 17;
};

/// The three-byte device ID from the signature row.
pub fn device_id() [3]u8 {
    return .{
        regs.read(regs.sigrow.deviceid0),
        regs.read(regs.sigrow.deviceid1),
        regs.read(regs.sigrow.deviceid2),
    };
}

/// Check that we are actually running on an AVR32DD20 (signature 1E 95 3A).
///
/// Worth calling once in start-up on a board that ships more than one DD
/// variant: the parts are pin-compatible, so the wrong binary flashes happily
/// and then misbehaves only when it runs off the end of a smaller flash.
pub fn is_expected_device() bool {
    return std.mem.eql(u8, &device_id(), &regs.sigrow.expected_device_id);
}

/// The 16-byte factory serial number.
pub fn serial_number() [regs.sigrow.sernum_len]u8 {
    var out: [regs.sigrow.sernum_len]u8 = undefined;
    for (&out, 0..) |*byte, i| {
        byte.* = regs.read(regs.sigrow.sernum0 + @as(u16, @intCast(i)));
    }
    return out;
}

/// Silicon revision, as it appears in SYSCFG.REVID. 0 is rev A.
pub fn revision() u8 {
    return regs.read(regs.syscfg.revid);
}

/// Revision as the letter Microchip prints on the package.
pub fn revision_letter() u8 {
    return 'A' + revision();
}

// -- Fuses -------------------------------------------------------------------

/// Fuse values as programmed. These are read-only from the running
/// application; changing them requires a programmer.
///
/// DS40002413 section 8 "Fuses (FUSE)". The AVR32DD20 layout is transcribed
/// from the ATDF FUSE register group.
pub const fuses = struct {
    pub fn watchdog_config() u8 {
        return regs.read(regs.fuse.wdtcfg);
    }

    pub fn bod_config() u8 {
        return regs.read(regs.fuse.bodcfg);
    }

    pub fn oscillator_config() u8 {
        return regs.read(regs.fuse.osccfg);
    }

    pub fn system_config0() u8 {
        return regs.read(regs.fuse.syscfg0);
    }

    pub fn system_config1() u8 {
        return regs.read(regs.fuse.syscfg1);
    }

    /// FUSE.SYSCFG0.EESAVE - whether a chip erase preserves the EEPROM.
    pub fn eeprom_preserved_on_erase() bool {
        return (system_config0() & 0x01) != 0;
    }

    /// FUSE.SYSCFG0.RSTPINCFG - what PF6 is wired to do.
    pub const ResetPinMode = enum(u8) {
        /// PF6 is an ordinary GPIO; only an HV pulse or UPDI can reset.
        gpio = 0x0,
        /// PF6 is the RESET input.
        reset = 0x1,
    };

    pub fn reset_pin_mode() ResetPinMode {
        return @enumFromInt((system_config0() & 0x08) >> 3);
    }

    /// FUSE.SYSCFG0.UPDIPINCFG - whether PF7 is still the UPDI programming
    /// pin. Clearing this frees PF7 as a GPIO but makes the part reachable
    /// only via a high-voltage UPDI entry sequence.
    pub fn updi_pin_enabled() bool {
        return (system_config0() & 0x10) != 0;
    }

    /// FUSE.SYSCFG1.SUT - the start-up delay after reset.
    pub fn startup_time() u3 {
        return @truncate(system_config1() & 0x07);
    }

    /// The flash section sizes, in units of the boot/code size granularity.
    pub fn code_size() u8 {
        return regs.read(regs.fuse.codesize);
    }

    pub fn boot_size() u8 {
        return regs.read(regs.fuse.bootsize);
    }
};

// -- General purpose registers ----------------------------------------------

/// Four bytes of scratch storage in the low I/O space that survive a soft
/// reset.
///
/// DS40002413 section 10 "GPR - General Purpose Registers", page 68. Because
/// they live in the low I/O space they are cheap to access, which makes them
/// the usual place to stash a reason code across a `reset.request()`.
pub const gpr = struct {
    pub const Index = enum(u2) { gpr0, gpr1, gpr2, gpr3 };

    fn address(index: Index) u16 {
        return regs.gpr.gpr0 + @as(u16, @intFromEnum(index));
    }

    pub fn read(index: Index) u8 {
        return regs.read(address(index));
    }

    pub fn write(index: Index, value: u8) void {
        regs.write(address(index), value);
    }
};
