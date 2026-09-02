//! WDT - Watchdog Timer.
//!
//! DS40002413 section 22 "WDT - Watchdog Timer", page 215.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=215

const microzig = @import("microzig");
const ccp = @import("ccp.zig");

const wdt = microzig.chip.peripherals.WDT;
const gen = microzig.chip.types.peripherals.WDT;

const CtrlABits = @TypeOf(wdt.CTRLA).underlying_type;

/// Time-out period, clocked from the 1.024 kHz output of OSC32K. The bracketed
/// times are nominal. Values re-exported from the generated WDT_PERIOD.
pub const Period = gen.WDT_PERIOD;

/// Closed window in window mode: a `reset()` before this has elapsed is itself
/// a fault and resets the device.
pub const Window = gen.WDT_WINDOW;

/// Issue the WDR instruction.
pub inline fn reset() void {
    asm volatile ("wdr");
}

const PeriodField = @FieldType(CtrlABits, "PERIOD");
const WindowField = @FieldType(CtrlABits, "WINDOW");

fn period_to_field(p: Period) PeriodField {
    return @fromBackingInt(@intCast(@backingInt(p)));
}

fn window_to_field(w: Window) WindowField {
    return @fromBackingInt(@intCast(@backingInt(w)));
}

/// Arm the watchdog in normal mode.
///
/// DS40002413 section 22.3.6 "Synchronization", page 218: CTRLA is written
/// across the WDT's own clock domain, so a write while STATUS.SYNCBUSY is set
/// is discarded. Wait for the previous write to land before issuing another.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=218
pub fn configure(period: Period) void {
    while (busy()) {}
    const addr = comptime @intFromPtr(&wdt.CTRLA);
    ccp.write_io(addr, @bitCast(CtrlABits{
        .PERIOD = period_to_field(period),
        .WINDOW = .OFF,
    }));
}

/// Arm the watchdog in window mode: `reset()` is only accepted in the interval
/// between `closed` and `open` elapsing.
///
/// DS40002413 section 22.3.3.2 "Window Mode", page 216.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=216
pub fn configure_windowed(closed: Window, open: Period) void {
    while (busy()) {}
    const addr = comptime @intFromPtr(&wdt.CTRLA);
    ccp.write_io(addr, @bitCast(CtrlABits{
        .PERIOD = period_to_field(open),
        .WINDOW = window_to_field(closed),
    }));
}

/// Stop the watchdog inside the change-enable window.
pub fn stop() void {
    configure(.OFF);
}

/// True while a CTRLA write is still synchronizing to the WDT clock domain.
pub fn busy() bool {
    return wdt.STATUS.read().SYNCBUSY != 0;
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
    const addr = comptime @intFromPtr(&wdt.STATUS);
    ccp.write_io(addr, 0b1000_0000);
}

/// True when fuse/WDT lock bits make the watchdog permanent.
pub fn locked() bool {
    return wdt.STATUS.read().LOCK != 0;
}
