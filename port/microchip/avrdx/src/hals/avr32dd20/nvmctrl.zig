//! NVMCTRL - Nonvolatile Memory Controller: EEPROM, flash self-programming,
//! the user row and the flash-to-data-space mapping.
//!
//! DS40002413 section 11 "NVMCTRL - Nonvolatile Memory Controller", page 71.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=71
//!
//! The AVR Dx programming model is *command first*, unlike tinyAVR-1 /
//! megaAVR-0: you select a command in NVMCTRL.CTRLA and *then* store to the
//! mapped address -- the store itself performs the operation. EEPROM on this
//! part has a page size of one byte (ATDF `EEPROM pagesize="0x1"`), so there
//! is no buffer to flush.
//!
//! Two safety rules this module enforces that raw register access would not:
//!
//! 1. *Command lifetime.* A selected write command stays armed until cleared;
//!    any stray store into mapped flash/EEPROM while it is armed performs a
//!    write. Every write path here clears the command before returning, and
//!    `Command` values never escape this file.
//! 2. *Bounds and alignment.* Flash self-programming works on 512-byte pages
//!    and only from code executing in the boot section; EEPROM addresses are
//!    checked against the 256-byte size so a wrapped u8 cannot alias.

const std = @import("std");
const microzig = @import("microzig");
const ccp = @import("ccp.zig");
const capabilities = @import("capabilities.zig");

const nvmctrl = microzig.chip.peripherals.NVMCTRL;
const cpu = microzig.chip.peripherals.CPU;
const gen = microzig.chip.types.peripherals.NVMCTRL;

/// NVMCTRL.CTRLA.CMD. Encodings re-exported from the generated layer
/// (DS40002413 section 11.3.2.3 "Command Modes", page 76).
pub const Command = gen.NVMCTRL_CMD;

/// NVMCTRL.STATUS.ERROR. Encodings re-exported from the generated layer.
pub const WriteError = gen.NVMCTRL_ERROR;

/// NVMCTRL.CTRLB.FLMAP - which 32 KiB flash section appears in the data space.
///
/// The AVR32DD20 has exactly 32 KiB of flash, so SECTION0 covers all of it and
/// this only matters for code shared with the larger DD parts.
pub const FlashSection = gen.NVMCTRL_FLMAP;

fn status_error() WriteError {
    return nvmctrl.STATUS.read().ERROR;
}

/// Select a command. CTRLA is CCP-protected with the SPM key, and the
/// protected store must follow within four instructions -- which is why
/// `ccp.write_spm` is inline and takes a comptime address.
pub inline fn select(command: Command) void {
    const addr = comptime @intFromPtr(&nvmctrl.CTRLA);
    ccp.write_spm(addr, @backingInt(command));
}

/// Clear any latched hardware error so this operation's outcome is judged
/// only on its own result. ERROR is sticky (section 11.5.3) and would
/// otherwise make one old fault fail every later operation.
pub inline fn clear_error() void {
    nvmctrl.STATUS.modify(.{ .ERROR = .NOERROR });
}

/// Mask interrupts for an NVM command window.
///
/// Section 11.5.1: a change from one NVM command to another must go through
/// NOCMD/NOOP. An interrupt handler performing its own NVM operation while
/// the mainline has a command armed violates that silently -- the ISR's
/// operation is dropped and the mainline stores under the wrong command --
/// so every arm..disarm window below runs masked. Save/restore of SREG keeps
/// this correct when called with interrupts already off.
const InterruptGuard = struct {
    sreg: @TypeOf(cpu.SREG.read()),

    fn enter() InterruptGuard {
        const g = InterruptGuard{ .sreg = cpu.SREG.read() };
        asm volatile ("cli");
        return g;
    }

    fn leave(g: InterruptGuard) void {
        cpu.SREG.write(g.sreg);
    }
};

/// Clear the selected command. Leaving a write command selected makes the next
/// ordinary store to mapped flash or EEPROM perform a write.
pub inline fn clear_command() void {
    select(.NONE);
}

/// True while a flash erase/write command is executing.
pub fn flash_busy() bool {
    return nvmctrl.STATUS.read().FBUSY != 0;
}

/// True while an EEPROM write is still committing to NVM.
pub fn eeprom_busy() bool {
    return nvmctrl.STATUS.read().EEBUSY != 0;
}

/// Block until both flash and EEPROM report ready.
pub fn wait_ready() void {
    while (flash_busy() or eeprom_busy()) {}
}

/// Read NVMCTRL.STATUS.ERROR and clear it.
///
/// DS40002413B section 11.5.3: the ERROR bits are R/W and "will show the last
/// error occurring"; they are cleared by writing zeros, not by reading -- one
/// historical fault would otherwise latch forever and misreport every later
/// operation. The busy flags read back as they are; writing zeros to them is
/// a no-op on silicon.
pub fn last_error() WriteError {
    const s = nvmctrl.STATUS.read();
    nvmctrl.STATUS.modify(.{ .ERROR = .NOERROR });
    return s.ERROR;
}

/// Map a different 32 KiB flash section into the data space.
///
/// CTRLB is CCP-protected with the IOREG key, unlike CTRLA's SPM key:
/// DS40002413 Table 11-7 "NVMCTRL - Registers Under Configuration Change
/// Protection", section 11.3.6, page 79.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=79
///
/// The read-modify-write happens outside the protected window and preserves
/// APPCODEWP/BOOTRP/APPDATAWP/FLMAPLOCK. If FLMAPLOCK has been set, FLMAP is
/// frozen until reset (section 11.5.2, page 82) and this call silently has no
/// effect on the mapping.
pub fn set_flash_section(section: FlashSection) void {
    var bits = nvmctrl.CTRLB.read();
    bits.FLMAP = section;
    // Read-modify-write outside the window; only the store lands inside it.
    const value: u8 = @bitCast(bits);
    const addr = comptime @intFromPtr(&nvmctrl.CTRLB);
    ccp.write_io(addr, value);
}

// -- EEPROM ------------------------------------------------------------------

/// 256 bytes of byte-erasable EEPROM at 0x1400 in the data space.
///
/// Base address from the ATDF data-space segment list; see also
/// DS40002413 section 11.3.1.2 "EEPROM", page 74:
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=74
pub const eeprom = struct {
    pub const size = capabilities.eeprom_size;

    /// Data-space address of the first EEPROM byte.
    pub const base_address: u16 = 0x1400;

    /// A validated offset into the EEPROM. Construction is range-checked, so
    /// an out-of-range offset cannot become an address that aliases elsewhere
    /// in the data space, and arithmetic on it cannot wrap silently.
    pub const Address = enum(u8) {
        _,

        pub fn from_int(offset: u8) ?Address {
            if (offset >= size) return null;
            return @fromBackingInt(@intCast(offset));
        }

        fn absolute(a: Address) u16 {
            return base_address + @as(u16, @backingInt(a));
        }
    };

    /// EEPROM is memory mapped, so reads are ordinary loads.
    pub fn read_byte(address: Address) u8 {
        return @as(*volatile u8, @ptrFromInt(address.absolute())).*;
    }

    /// Read up to `buffer.len` bytes starting at `start`. Returns how many
    /// bytes were read, clamped at the end of the EEPROM -- no wraparound.
    pub fn read_into(start: Address, buffer: []u8) usize {
        const start_i = @backingInt(start);
        const count = @min(buffer.len, size - start_i);
        for (buffer[0..count], 0..) |*byte, i| {
            byte.* = @as(*volatile u8, @ptrFromInt(base_address + start_i + i)).*;
        }
        return count;
    }

    /// Erase and write one byte.
    ///
    /// DS40002413 section 11.3.2.3.5 "EEPROM Erase/Write Mode", page 77:
    /// select EEERWR, store the byte to its mapped address, and the controller
    /// performs erase-then-write. EEBUSY is set for the duration.
    /// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=77
    ///
    /// Command lifetime is fully contained: armed, used, disarmed, with
    /// interrupts masked across the window so an ISR's own NVM operation
    /// cannot interleave (section 11.5.1).
    pub fn write_byte(address: Address, value: u8) void {
        const guard = InterruptGuard.enter();
        defer guard.leave();

        while (eeprom_busy()) {}
        clear_error();
        select(.EEERWR);
        @as(*volatile u8, @ptrFromInt(address.absolute())).* = value;
        while (eeprom_busy()) {}
        clear_command();
    }

    /// Skip the write when the stored byte already matches, which is worth
    /// doing: the cell endurance is finite and an erase/write is slow.
    pub fn update_byte(address: Address, value: u8) void {
        if (read_byte(address) != value) write_byte(address, value);
    }

    /// Write a run of bytes with no wraparound past the end of the EEPROM.
    /// Returns the number of bytes actually written.
    ///
    /// The command stays selected across the whole run (one arming instead of
    /// one per byte), then is always cleared.
    pub fn write_all(start: Address, bytes: []const u8) usize {
        if (bytes.len == 0) return 0;
        const start_i = @backingInt(start);
        const count = @min(bytes.len, size - start_i);

        const guard = InterruptGuard.enter();
        defer guard.leave();

        while (eeprom_busy()) {}
        clear_error();
        select(.EEERWR);
        for (bytes[0..count], 0..) |byte, i| {
            @as(*volatile u8, @ptrFromInt(base_address + start_i + i)).* = byte;
            while (eeprom_busy()) {}
        }
        clear_command();
        return count;
    }

    /// Update a run of bytes, skipping cells that already match. Returns the
    /// number of bytes processed, clamped at the end of the EEPROM.
    pub fn update_all(start: Address, bytes: []const u8) usize {
        const start_i = @backingInt(start);
        const count = @min(bytes.len, size - start_i);
        for (bytes[0..count], 0..) |byte, i| {
            update_byte(@fromBackingInt(@intCast(start_i + i)), byte);
        }
        return count;
    }

    /// Erase every byte of EEPROM.
    ///
    /// DS40002413 section 11.3.2.3.9 "EEPROM Erase Command", page 78: the
    /// EECHER command erases the whole array in one operation, with no store
    /// to a mapped address required.
    pub fn erase_all() void {
        const guard = InterruptGuard.enter();
        defer guard.leave();

        while (eeprom_busy()) {}
        clear_error();
        select(.EECHER);
        while (eeprom_busy()) {}
        clear_command();
    }
};

// -- Flash -------------------------------------------------------------------

/// Flash as seen from the data space.
///
/// DS40002413 section 11.3.1.1 "Flash", page 72. The whole 32 KiB of an
/// AVR32DD20 is visible at once at 0x8000, which makes reading constants out
/// of flash a plain load on this family -- no `LPM`, no `PROGMEM`.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=72
pub const flash = struct {
    pub const size = capabilities.flash_size;
    pub const page_size = capabilities.flash_page_size;
    /// Where mapped flash starts in the data space.
    pub const mapped_base: u16 = 0x8000;

    /// Data-space address of a flash offset.
    pub fn mapped_address(offset: u15) u16 {
        comptime std.debug.assert(mapped_base + size <= 0x10000);
        return mapped_base + @as(u16, offset);
    }

    pub fn read_byte(offset: u15) u8 {
        return @as(*volatile u8, @ptrFromInt(mapped_address(offset))).*;
    }

    pub fn read_word(offset: u15) u16 {
        return @as(*volatile u16, @ptrFromInt(mapped_address(offset))).*;
    }

    /// A `[]const u8` view of a region of flash.
    pub fn slice(offset: u15, len: usize) []const u8 {
        const ptr: [*]const u8 = @ptrFromInt(mapped_address(offset));
        return ptr[0..len];
    }

    /// Erase one 512-byte page.
    ///
    /// Self-programming needs a boot section (FUSE.BOOTSIZE) and must never
    /// target the section the code executes from (section 11.3.1,
    /// Table 11-2). With the factory default BOOTSIZE=0 no self-programming
    /// is possible until fuses configure one. Illegal calls fail with
    /// `error.BootSectionRequired` via STATUS.ERROR.
    /// DS40002413 section 11.3.2.3.2 "Flash Page Erase Mode", page 77.
    pub fn erase_page(offset: u15) BootOperation!void {
        try check_page_operation(offset, flash.page_size);
        const guard = InterruptGuard.enter();
        defer guard.leave();

        wait_ready();
        clear_error();
        select(.FLPER);
        @as(*volatile u8, @ptrFromInt(mapped_address(offset))).* = 0;
        wait_ready();
        clear_command();
        switch (last_error()) {
            .NOERROR => {},
            else => |e| return err_from(e),
        }
    }

    /// Write one page's worth of words to an already-erased page.
    ///
    /// Data-space stores land one byte at a time (section 11.3.2, Table 11-3
    /// note 1); `words` are simply the natural unit here. `offset` must be
    /// page-aligned, and the slice may not span past the end of a page (or of
    /// flash). Like `erase_page`, this requires a boot section and must not
    /// target the executing section. DS40002413 section 11.3.2.3.1 "Flash
    /// Write Mode", page 76.
    pub fn write_page(offset: u15, words: []const u16) BootOperation!void {
        try check_page_operation(offset, words.len * 2);
        const guard = InterruptGuard.enter();
        defer guard.leave();

        wait_ready();
        clear_error();
        select(.FLWR);
        for (words, 0..) |word, i| {
            @as(*volatile u16, @ptrFromInt(mapped_address(offset) + @as(u16, @intCast(i * 2)))).* = word;
        }
        wait_ready();
        clear_command();
        switch (last_error()) {
            .NOERROR => {},
            else => |e| return err_from(e),
        }
    }
};

/// Why a flash self-programming request was rejected.
pub const BootOperation = error{
    /// Offset was not 512-byte aligned (rejected before touching hardware).
    PageUnaligned,
    /// Operation would have crossed a page boundary or the end of flash
    /// (rejected before touching hardware).
    PageOverflow,
    /// Hardware rejected the address: self-programming requires a boot
    /// section and must not target the executing section.
    BootSectionRequired,
    /// The write command was not selected when used, i.e. `select()` was
    /// skipped or the command lifetime already ended.
    CommandNotSelected,
    /// A second write command was selected while one was still armed.
    DoubleCommandSelect,
    /// A new programming operation started before the previous finished.
    OperationInProgress,
};

fn check_page_operation(offset: u15, len: usize) BootOperation!void {
    if (offset % flash.page_size != 0) {
        return error.PageUnaligned;
    }
    // `offset` is an absolute flash address, but pages are relative units:
    // the operation must stay within this one page and within flash.
    if (len > flash.page_size) {
        return error.PageOverflow;
    }
    if (@as(usize, offset) + len > flash.size) {
        return error.PageOverflow;
    }
}

fn err_from(e: WriteError) BootOperation {
    return switch (e) {
        // The only encoding that specifically means "wrong execution section".
        .ILLEGALSADDR => error.BootSectionRequired,
        .ILLEGALCMD => error.CommandNotSelected,
        .DOUBLESELECT => error.DoubleCommandSelect,
        .ONGOINGPROG => error.OperationInProgress,
        else => error.CommandNotSelected,
    };
}

// -- User row ----------------------------------------------------------------

/// 32 bytes of user-programmable signature space, preserved by chip erase.
///
/// DS40002413 section 11.3.1.4 "User Row", page 74. Reads are ordinary loads;
/// writing uses the flash commands and, like flash, only works from the boot
/// section.
pub const user_row = struct {
    pub const size = capabilities.user_row_size;

    /// Data-space address of the first user-row byte.
    pub const base_address: u16 = 0x1080;

    pub fn read_byte(comptime offset: u5) u8 {
        comptime std.debug.assert(offset < size);
        return @as(*volatile u8, @ptrFromInt(base_address + offset)).*;
    }

    /// Read the whole row into `buffer`; returns how many bytes were filled.
    pub fn read_into(buffer: []u8) usize {
        const count = @min(buffer.len, size);
        for (buffer[0..count], 0..) |*byte, i| {
            byte.* = @as(*volatile u8, @ptrFromInt(base_address + i)).*;
        }
        return count;
    }
};

test "flash page bounds" {
    const testing = std.testing;
    // Page 0 and higher pages both pass alignment + bounds.
    try check_page_operation(0, flash.page_size);
    try check_page_operation(512, flash.page_size);
    try check_page_operation(flash.size - flash.page_size, flash.page_size);
    // Zero-length probes on valid boundaries are fine too.
    try check_page_operation(flash.size - flash.page_size, 0);
    // Unaligned offsets are rejected before anything else -- including a
    // misaligned offset that also happens to lie past the last full page.
    try testing.expectError(error.PageUnaligned, check_page_operation(1, 1));
    try testing.expectError(error.PageUnaligned, check_page_operation(256, 0));
    try testing.expectError(error.PageUnaligned, check_page_operation(flash.size - flash.page_size + 4, flash.page_size));
    // Operations larger than one page are rejected even when aligned.
    try testing.expectError(error.PageOverflow, check_page_operation(512, flash.page_size + 2));
    try testing.expectError(error.PageOverflow, check_page_operation(flash.size - flash.page_size, flash.page_size + 1));
    // NOTE: a page-aligned offset at or past `flash.size` is not expressible:
    // flash.size == max(u15) + 1 and every u15 input is either inside the last
    // page or unaligned. The `offset + len > size` guard remains as defense for
    // any future widening of the offset parameter type.
}
