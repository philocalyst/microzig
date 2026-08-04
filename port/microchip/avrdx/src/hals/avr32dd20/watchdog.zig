//! WDT - Watchdog Timer.
//!
//! DS40002413 section 22 "WDT - Watchdog Timer", page 215.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=215

const regs = @import("registers.zig");
const ccp = @import("ccp.zig");

/// Time-out period, clocked from the 1.024 kHz output of OSC32K. The bracketed
/// times are nominal.
pub const Period = enum(u8) {
    off = 0x0,
    cycles8 = 0x1, // 8 ms
    cycles16 = 0x2, // 16 ms
    cycles32 = 0x3, // 32 ms
    cycles64 = 0x4, // 64 ms
    cycles128 = 0x5, // 0.128 s
    cycles256 = 0x6, // 0.256 s
    cycles512 = 0x7, // 0.512 s
    cycles1k = 0x8, // 1.0 s
    cycles2k = 0x9, // 2.0 s
    cycles4k = 0xA, // 4.1 s
    cycles8k = 0xB, // 8.2 s
};

/// Closed window in window mode: a `reset()` before this has elapsed is itself
/// a fault and resets the device.
pub const Window = Period;

/// Issue the WDR instruction.
pub inline fn reset() void {
    asm volatile ("wdr");
}

/// Arm the watchdog in normal mode.
///
/// DS40002413 section 22.3.6 "Synchronization", page 218: CTRLA is written
/// across the WDT's own clock domain, so a write while STATUS.SYNCBUSY is set
/// is discarded. Wait for the previous write to land before issuing another.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=218
pub fn configure(period: Period) void {
    while (busy()) {}
    ccp.write_io(regs.wdt.ctrla, @intFromEnum(period));
}

/// Arm the watchdog in window mode: `reset()` is only accepted in the interval
/// between `closed` and `open` elapsing.
///
/// DS40002413 section 22.3.3.2 "Window Mode", page 216.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=216
pub fn configure_windowed(closed: Window, open: Period) void {
    while (busy()) {}
    ccp.write_io(
        regs.wdt.ctrla,
        @intFromEnum(open) | (@as(u8, @intFromEnum(closed)) << 4),
    );
}

pub fn stop() void {
    configure(.off);
}

/// True while a CTRLA write is still synchronizing to the WDT clock domain.
pub fn busy() bool {
    return (regs.read(regs.wdt.status) & regs.bit(regs.wdt.syncbusy)) != 0;
}

/// Freeze the current configuration until the next reset.
///
/// DS40002413 section 22.3.3.3 "Preventing Unintentional Changes", page 217:
/// once STATUS.LOCK is set, CTRLA is read-only for software. Note that when
/// the watchdog is enabled by fuse, LOCK is already set out of reset and this
/// call is redundant.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=217
pub fn lock() void {
    while (busy()) {}
    ccp.write_io(regs.wdt.status, regs.bit(regs.wdt.lock));
}

pub fn locked() bool {
    return (regs.read(regs.wdt.status) & regs.bit(regs.wdt.lock)) != 0;
}
