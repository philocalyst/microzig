//! NVMCTRL - Nonvolatile Memory Controller: EEPROM, flash self-programming,
//! the user row and the flash-to-data-space mapping.
//!
//! DS40002413 section 11 "NVMCTRL - Nonvolatile Memory Controller", page 71.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=71
//!
//! The AVR Dx programming model is *command first*, and is not the same as the
//! tinyAVR-1 / megaAVR-0 one that most AVR Zig code is ported from. There the
//! sequence was "fill the mapped page buffer, then issue PAGEERASEWRITE"; here
//! you select a command in NVMCTRL.CTRLA and *then* store to the mapped
//! address, and the store itself performs the operation. EEPROM on this part
//! also has a page size of one byte (ATDF `EEPROM pagesize="0x1"`), so there
//! is no buffer to flush.

const regs = @import("registers.zig");
const ccp = @import("ccp.zig");

/// NVMCTRL.CTRLA.CMD.
///
/// DS40002413 section 11.3.2.3 "Command Modes", page 76.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=76
pub const Command = enum(u8) {
    /// Clear the selected command. Always return to this when done.
    none = 0x00,
    no_operation = 0x01,
    /// Write flash. The target page must already be erased.
    flash_write = 0x02,
    flash_page_erase = 0x08,
    flash_multi_page_erase_2 = 0x09,
    flash_multi_page_erase_4 = 0x0A,
    flash_multi_page_erase_8 = 0x0B,
    flash_multi_page_erase_16 = 0x0C,
    flash_multi_page_erase_32 = 0x0D,
    /// Write EEPROM without erasing first; only clears bits.
    eeprom_write = 0x12,
    /// Erase and write EEPROM in one operation. The usual choice.
    eeprom_erase_write = 0x13,
    eeprom_byte_erase = 0x18,
    eeprom_multi_byte_erase_2 = 0x19,
    eeprom_multi_byte_erase_4 = 0x1A,
    eeprom_multi_byte_erase_8 = 0x1B,
    eeprom_multi_byte_erase_16 = 0x1C,
    eeprom_multi_byte_erase_32 = 0x1D,
    /// Erase the whole device, including EEPROM.
    chip_erase = 0x20,
    /// Erase the whole EEPROM.
    eeprom_erase = 0x30,
};

/// NVMCTRL.STATUS.ERROR - why the last operation was rejected.
pub const WriteError = enum(u8) {
    none = 0x0,
    /// No write command was selected.
    illegal_command = 0x1,
    /// Write to a section the current section is not allowed to write.
    illegal_address = 0x2,
    /// A new command was selected while one was already selected.
    double_select = 0x3,
    /// A new operation started before the previous one finished.
    ongoing_programming = 0x4,
    _,
};

/// NVMCTRL.CTRLB.FLMAP - which 32 KiB flash section appears in the data space.
///
/// The AVR32DD20 has exactly 32 KiB of flash, so `section0` covers all of it
/// and this only matters for code shared with the larger DD parts.
pub const FlashSection = enum(u8) {
    section0 = 0x0,
    section1 = 0x1,
    section2 = 0x2,
    section3 = 0x3,
};

/// Select a command. CTRLA is CCP-protected with the SPM key, and the
/// protected store must follow within four instructions -- which is why
/// `ccp.write_spm` is inline and takes a comptime address.
pub inline fn select(command: Command) void {
    ccp.write_spm(regs.nvmctrl.ctrla, @intFromEnum(command));
}

/// Clear the selected command. Leaving a write command selected makes the next
/// ordinary store to mapped flash or EEPROM perform a write.
pub inline fn clear_command() void {
    select(.none);
}

pub fn flash_busy() bool {
    return (regs.read(regs.nvmctrl.status) & regs.bit(regs.nvmctrl.fbusy)) != 0;
}

pub fn eeprom_busy() bool {
    return (regs.read(regs.nvmctrl.status) & regs.bit(regs.nvmctrl.eebusy)) != 0;
}

pub fn wait_ready() void {
    while ((regs.read(regs.nvmctrl.status) &
        (regs.bit(regs.nvmctrl.fbusy) | regs.bit(regs.nvmctrl.eebusy))) != 0)
    {}
}

/// Read and clear NVMCTRL.STATUS.ERROR.
pub fn last_error() WriteError {
    const status = regs.read(regs.nvmctrl.status);
    return @enumFromInt((status & regs.nvmctrl.error_mask) >> 4);
}

/// Map a different 32 KiB flash section into the data space.
///
/// CTRLB is CCP-protected with the IOREG key, unlike CTRLA's SPM key:
/// DS40002413 Table 11-7 "NVMCTRL - Registers Under Configuration Change
/// Protection", section 11.3.6, page 79.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=79
///
/// The read-modify-write preserves APPCODEWP/BOOTRP/APPDATAWP and FLMAPLOCK.
/// If FLMAPLOCK has been set, FLMAP is frozen until reset (section 11.5.2,
/// page 82) and this call silently has no effect on the mapping.
pub fn set_flash_section(section: FlashSection) void {
    // Read outside the window: only the store may land inside the four
    // instructions that follow the key write.
    const current = regs.read(regs.nvmctrl.ctrlb) & ~regs.nvmctrl.flmap_mask;
    ccp.write_io(
        regs.nvmctrl.ctrlb,
        current | (@as(u8, @intFromEnum(section)) << regs.nvmctrl.flmap_shift),
    );
}

// -- EEPROM ------------------------------------------------------------------

/// 256 bytes of byte-erasable EEPROM at 0x1400 in the data space.
///
/// DS40002413 section 11.3.1.2 "EEPROM", page 74.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=74
pub const eeprom = struct {
    pub const size = regs.memory.eeprom_size;

    /// A validated offset into the EEPROM. Wrapping the offset in a type keeps
    /// a raw data-space address from being passed here by accident.
    pub const Address = enum(u8) {
        _,

        pub fn from_int(offset: u8) Address {
            return @enumFromInt(offset);
        }

        fn absolute(a: Address) u16 {
            return regs.memory.eeprom_base + @as(u16, @intFromEnum(a));
        }
    };

    /// EEPROM is memory mapped, so reads are ordinary loads.
    pub fn read_byte(address: Address) u8 {
        return regs.mem8(address.absolute()).*;
    }

    pub fn read_into(start: Address, buffer: []u8) void {
        for (buffer, 0..) |*byte, i| {
            byte.* = regs.mem8(start.absolute() + @as(u16, @intCast(i))).*;
        }
    }

    /// Erase and write one byte.
    ///
    /// DS40002413 section 11.3.2.3.5 "EEPROM Erase/Write Mode", page 77:
    /// select EEERWR, store the byte to its mapped address, and the controller
    /// performs erase-then-write. EEBUSY is set for the duration.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=77
    pub fn write_byte(address: Address, value: u8) void {
        while (eeprom_busy()) {}
        select(.eeprom_erase_write);
        regs.mem8(address.absolute()).* = value;
        while (eeprom_busy()) {}
        clear_command();
    }

    /// Skip the write when the stored byte already matches, which is worth
    /// doing: the cell endurance is finite and an erase/write is slow.
    pub fn update_byte(address: Address, value: u8) void {
        if (read_byte(address) != value) write_byte(address, value);
    }

    /// Write a run of bytes, holding the command selected across the whole run
    /// instead of re-arming it per byte.
    pub fn write_all(start: Address, bytes: []const u8) void {
        if (bytes.len == 0) return;
        while (eeprom_busy()) {}
        select(.eeprom_erase_write);
        for (bytes, 0..) |byte, i| {
            regs.mem8(start.absolute() + @as(u16, @intCast(i))).* = byte;
            while (eeprom_busy()) {}
        }
        clear_command();
    }

    pub fn update_all(start: Address, bytes: []const u8) void {
        for (bytes, 0..) |byte, i| {
            update_byte(@enumFromInt(@intFromEnum(start) +% @as(u8, @intCast(i))), byte);
        }
    }

    /// Erase every byte of EEPROM.
    pub fn erase_all() void {
        while (eeprom_busy()) {}
        select(.eeprom_erase);
        while (eeprom_busy()) {}
        clear_command();
    }
};

// -- Flash -------------------------------------------------------------------

/// Flash as seen from the data space.
///
/// DS40002413 section 11.3.1.1 "Flash", page 72. The whole 32 KiB of an
/// AVR32DD20 is visible at once at 0x8000, which is what makes reading
/// constants out of flash a plain load on this family -- there is no `LPM`
/// dance and no `PROGMEM`-style attribute needed.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=72
pub const flash = struct {
    pub const size = regs.memory.flash_size;
    pub const page_size = regs.memory.flash_page_size;
    pub const mapped_base = regs.memory.mapped_progmem_base;

    /// Data-space address of a flash offset.
    pub fn mapped_address(offset: u15) u16 {
        return mapped_base + @as(u16, offset);
    }

    pub fn read_byte(offset: u15) u8 {
        return regs.mem8(mapped_address(offset)).*;
    }

    pub fn read_word(offset: u15) u16 {
        return regs.mem16(mapped_address(offset)).*;
    }

    /// A `[]const u8` view of a region of flash.
    pub fn slice(offset: u15, len: usize) []const u8 {
        const ptr: [*]const u8 = @ptrFromInt(mapped_address(offset));
        return ptr[0..len];
    }

    /// Erase one 512-byte page.
    ///
    /// Self-programming only works from code running in the boot section; a
    /// call from the application section fails with `WriteError.illegal_address`.
    /// DS40002413 section 11.3.2.3.2 "Flash Page Erase Mode", page 77.
    pub fn erase_page(offset: u15) void {
        wait_ready();
        select(.flash_page_erase);
        regs.mem8(mapped_address(offset)).* = 0;
        wait_ready();
        clear_command();
    }

    /// Write one page's worth of words to an already-erased page.
    ///
    /// Flash is word-organized, so `words` is written 16 bits at a time and
    /// `offset` must be page-aligned.
    /// DS40002413 section 11.3.2.3.1 "Flash Write Mode", page 76.
    pub fn write_page(offset: u15, words: []const u16) void {
        wait_ready();
        select(.flash_write);
        for (words, 0..) |word, i| {
            regs.mem16(mapped_address(offset) + @as(u16, @intCast(i * 2))).* = word;
        }
        wait_ready();
        clear_command();
    }
};

// -- User row ----------------------------------------------------------------

/// 32 bytes of user-programmable signature space, preserved by a chip erase.
///
/// DS40002413 section 11.3.1.4 "User Row", page 74. Reads are ordinary loads;
/// writing it uses the flash commands and, like flash, only works from the
/// boot section.
pub const user_row = struct {
    pub const size = regs.memory.user_row_size;

    pub fn read_byte(offset: u5) u8 {
        return regs.mem8(regs.memory.user_row_base + @as(u16, offset)).*;
    }

    pub fn read_into(buffer: []u8) void {
        for (buffer, 0..) |*byte, i| {
            byte.* = regs.mem8(regs.memory.user_row_base + @as(u16, @intCast(i))).*;
        }
    }
};
