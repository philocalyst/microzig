//! CRCSCAN - Cyclic Redundancy Check Memory Scan.
//!
//! DS40002413 section 30 "CRCSCAN - Cyclic Redundancy Check Memory Scan",
//! page 453.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=453
//!
//! Continuously checks flash against a CRC stored at the end of the scanned
//! section, in the background, without CPU involvement. Intended for
//! functional-safety designs that need to detect flash corruption.

const regs = @import("registers.zig");

/// CRCSCAN.CTRLB.SRC - how much of flash to scan.
pub const Source = enum(u8) {
    /// The whole flash.
    flash = 0x0,
    /// The boot and application code sections.
    boot_and_application = 0x1,
    /// The boot section only, which is the quickest useful check.
    boot = 0x2,
};

/// Start a scan.
///
/// `non_maskable` promotes a CRC failure to an NMI, which cannot be masked or
/// disabled again before reset -- the right choice when a corrupt flash should
/// never be allowed to keep running. The CRC value itself must have been
/// programmed at the end of the selected section, normally by the programming
/// tool.
pub fn start(source: Source, non_maskable: bool) void {
    regs.write(regs.crcscan.ctrlb, @intFromEnum(source));
    regs.write(
        regs.crcscan.ctrla,
        regs.bit(regs.crcscan.enable) |
            (if (non_maskable) regs.bit(regs.crcscan.nmien) else 0),
    );
}

pub fn stop() void {
    regs.write(regs.crcscan.ctrla, 0);
}

/// Restart the scan from the beginning.
pub fn restart() void {
    regs.set_bits(regs.crcscan.ctrla, regs.bit(regs.crcscan.reset));
}

pub fn busy() bool {
    return (regs.read(regs.crcscan.status) & regs.bit(regs.crcscan.busy)) != 0;
}

/// True when the last completed scan matched.
///
/// Only meaningful once `busy()` is false; it reads as 0 while a scan is in
/// flight, so polling it without checking `busy()` looks like a failure.
pub fn ok() bool {
    return (regs.read(regs.crcscan.status) & regs.bit(regs.crcscan.ok)) != 0;
}

/// Run one scan to completion and report whether flash matched.
pub fn verify_blocking(source: Source) bool {
    start(source, false);
    while (busy()) {}
    const result = ok();
    stop();
    return result;
}
