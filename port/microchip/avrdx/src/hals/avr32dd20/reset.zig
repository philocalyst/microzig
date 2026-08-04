//! RSTCTRL - Reset Controller.
//!
//! DS40002413 section 14 "RSTCTRL - Reset Controller", page 120.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=120

const regs = @import("registers.zig");
const ccp = @import("ccp.zig");

/// Why the device last reset. More than one flag can be set at a time, so this
/// is a bit set rather than an enum.
pub const Flags = packed struct(u8) {
    /// Power-on reset.
    power_on: bool = false,
    /// Brown-out detector reset.
    brown_out: bool = false,
    /// External reset via the RESET pin.
    external: bool = false,
    /// Watchdog time-out.
    watchdog: bool = false,
    /// Software reset, i.e. a previous call to `request()`.
    software: bool = false,
    /// Reset requested over the UPDI debug interface.
    updi: bool = false,
    _reserved: u2 = 0,

    pub fn any(f: Flags) bool {
        return @as(u8, @bitCast(f)) != 0;
    }
};

/// Read RSTCTRL.RSTFR.
///
/// DS40002413 section 14.5.1 "Reset Flag Register", page 127: the flags are
/// cumulative and are only cleared by a power-on reset or by writing ones, so
/// firmware that cares about the reset source should `clear_flags()` after
/// reading -- otherwise the next boot sees stale bits.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=127
pub fn flags() Flags {
    return @bitCast(regs.read(regs.rstctrl.rstfr));
}

/// Clear the flags that are set in `mask` (write-one-to-clear).
pub fn clear_flags(mask: Flags) void {
    regs.write(regs.rstctrl.rstfr, @bitCast(mask));
}

pub fn clear_all_flags() void {
    regs.write(regs.rstctrl.rstfr, 0x3F);
}

/// Read and clear in one step, which is what most start-up code wants.
pub fn take_flags() Flags {
    const f = flags();
    clear_flags(f);
    return f;
}

/// Reset the device immediately.
///
/// DS40002413 section 14.3.2.1.5 "Software Reset (SWRST)", page 123: SWRR is
/// CCP-protected, and the reset happens on the write itself, so this never
/// returns.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=123
pub fn request() noreturn {
    ccp.write_io(regs.rstctrl.swrr, regs.bit(regs.rstctrl.swrst));
    unreachable;
}
