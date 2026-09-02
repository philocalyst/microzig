//! Device identity: signature row, fuses, general purpose registers and the
//! system configuration block.
//!
//! DS40002413 section 9 "Peripherals and Architecture", page 63, and
//! section 11.3.1.3 "Signature Row", page 74.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=74

const std = @import("std");
const microzig = @import("microzig");
const capabilities = @import("capabilities.zig");

const chip = microzig.chip.peripherals;

/// Static facts about this part. Geometry and frequency limits live in
/// `capabilities.zig`; see that file for why the CPU is rated 24 MHz even
/// though the ATDF variant carries speedmax="32000000".
pub const info = struct {
    pub const name = capabilities.name;
    pub const flash_size = capabilities.flash_size;
    pub const flash_page_size = capabilities.flash_page_size;
    pub const sram_size = capabilities.sram_size;
    pub const eeprom_size = capabilities.eeprom_size;
    pub const user_row_size = capabilities.user_row_size;
    /// Maximum rated CLK_MAIN/CPU frequency.
    pub const max_frequency_hz = capabilities.max_frequency_hz;
    pub const vcc_min_mv = capabilities.vcc_min_mv;
    pub const vcc_max_mv = capabilities.vcc_max_mv;
    /// The 20-pin package bonds 17 I/O pads: PA0-PA7, PC1-PC3, PD4-PD7,
    /// PF6-PF7; 16 of them can drive.
    pub const io_pin_count = capabilities.Port.count_bonded;
    pub const output_pin_count = capabilities.Port.count_output_capable;
};

/// The three-byte device ID from the signature row.
pub fn device_id() [3]u8 {
    return .{
        chip.SIGROW.DEVICEID0,
        chip.SIGROW.DEVICEID1,
        chip.SIGROW.DEVICEID2,
    };
}

/// Check that we are actually running on an AVR32DD20 (signature 1E 95 3A).
///
/// Worth calling once in start-up on a board that ships more than one DD
/// variant: the parts are pin-compatible, so the wrong binary flashes happily
/// and then misbehaves only when it runs off the end of a smaller flash.
pub fn is_expected_device() bool {
    return std.mem.eql(u8, &device_id(), &capabilities.expected_device_id);
}

/// The 16-byte factory serial number.
pub fn serial_number() [16]u8 {
    return .{
        chip.SIGROW.SERNUM0,
        chip.SIGROW.SERNUM1,
        chip.SIGROW.SERNUM2,
        chip.SIGROW.SERNUM3,
        chip.SIGROW.SERNUM4,
        chip.SIGROW.SERNUM5,
        chip.SIGROW.SERNUM6,
        chip.SIGROW.SERNUM7,
        chip.SIGROW.SERNUM8,
        chip.SIGROW.SERNUM9,
        chip.SIGROW.SERNUM10,
        chip.SIGROW.SERNUM11,
        chip.SIGROW.SERNUM12,
        chip.SIGROW.SERNUM13,
        chip.SIGROW.SERNUM14,
        chip.SIGROW.SERNUM15,
    };
}

/// Silicon revision, as it appears in SYSCFG.REVID. 0 is rev A.
pub fn revision() u8 {
    return chip.SYSCFG.REVID;
}

/// Revision as the letter Microchip prints on the package.
pub fn revision_letter() u8 {
    return 'A' + revision();
}

// -- Fuses -------------------------------------------------------------------

/// Fuse values as programmed. These are read-only from the running
/// application; changing them requires a programmer.
///
/// DS40002413 section 8 "Fuses (FUSE)". Layout comes from the generated FUSE
/// peripheral (ATDF FUSE register group).
pub const fuses = struct {
    pub fn watchdog_config() u8 {
        return chip.FUSE.WDTCFG.raw;
    }

    pub fn bod_config() u8 {
        return chip.FUSE.BODCFG.raw;
    }

    pub fn oscillator_config() u8 {
        return chip.FUSE.OSCCFG.raw;
    }

    pub fn system_config0() u8 {
        return chip.FUSE.SYSCFG0.raw;
    }

    pub fn system_config1() u8 {
        return chip.FUSE.SYSCFG1.raw;
    }

    /// FUSE.SYSCFG0.EESAVE - whether a chip erase preserves the EEPROM.
    pub fn eeprom_preserved_on_erase() bool {
        return chip.FUSE.SYSCFG0.read().EESAVE != 0;
    }

    /// FUSE.SYSCFG0.RSTPINCFG - what PF6 is wired to do.
    pub const ResetPinMode = enum(u1) {
        /// PF6 is an ordinary GPIO; only an HV pulse or UPDI can reset.
        gpio = 0x0,
        /// PF6 is the RESET input.
        reset = 0x1,
    };

    pub fn reset_pin_mode() ResetPinMode {
        return @fromBackingInt(@intCast(chip.FUSE.SYSCFG0.read().RSTPINCFG));
    }

    /// FUSE.SYSCFG0.UPDIPINCFG - whether PF7 is still the UPDI programming
    /// pin. Clearing this frees PF7 as a GPIO but makes the part reachable
    /// only via a high-voltage UPDI entry sequence.
    pub fn updi_pin_enabled() bool {
        return chip.FUSE.SYSCFG0.read().UPDIPINCFG != 0;
    }

    /// FUSE.SYSCFG1.MVSYSCFG - how MVIO is wired.
    pub const MvioSystemConfig = enum(u2) {
        dual_supply = 0x1,
        single_supply = 0x2,
        _,
    };

    pub fn mvio_system_config() MvioSystemConfig {
        return @fromBackingInt(@intCast(chip.FUSE.SYSCFG1.read().MVSYSCFG));
    }

    /// FUSE.SYSCFG1.SUT - the start-up delay after reset.
    pub fn startup_time() u3 {
        return @backingInt(chip.FUSE.SYSCFG1.read().SUT);
    }

    /// The flash section sizes, in units of the boot/code size granularity.
    pub fn code_size() u8 {
        return chip.FUSE.CODESIZE;
    }

    pub fn boot_size() u8 {
        return chip.FUSE.BOOTSIZE;
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

    pub fn read(index: Index) u8 {
        return switch (index) {
            .gpr0 => chip.GPR.GPR0,
            .gpr1 => chip.GPR.GPR1,
            .gpr2 => chip.GPR.GPR2,
            .gpr3 => chip.GPR.GPR3,
        };
    }

    pub fn write(index: Index, value: u8) void {
        switch (index) {
            .gpr0 => chip.GPR.GPR0 = value,
            .gpr1 => chip.GPR.GPR1 = value,
            .gpr2 => chip.GPR.GPR2 = value,
            .gpr3 => chip.GPR.GPR3 = value,
        }
    }
};
