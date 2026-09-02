//! CRCSCAN - Cyclic Redundancy Check Memory Scan.
//!
//! DS40002413 section 30 "CRCSCAN - Cyclic Redundancy Check Memory Scan",
//! page 453.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=453
//!
//! Continuously checks flash against a CRC stored at the end of the scanned
//! section, in the background, without CPU involvement. Intended for
//! functional-safety designs that need to detect flash corruption.

const microzig = @import("microzig");

const crcscan = microzig.chip.peripherals.CRCSCAN;
const gen = microzig.chip.types.peripherals.CRCSCAN;

/// CRCSCAN.CTRLB.SRC - how much of flash to scan. Encodings re-exported from
/// the generated layer.
pub const Source = gen.CRCSCAN_SRC;

/// Start a CRC scan over `source`.
///
/// `non_maskable` promotes a CRC failure to an NMI, which cannot be masked or
/// disabled again before reset -- the right choice when a corrupt flash should
/// never be allowed to keep running. The CRC value itself must have been
/// programmed at the end of the selected section, normally by the programming
/// tool.
///
/// Section 30.5.2: CTRLB "is not writable when the CRCSCAN is busy", so any
/// scan still running is reset first -- otherwise the SRC write silently
/// lands on stale configuration and rescans the previous source.
pub fn start(source: Source, non_maskable: bool) void {
    if (busy()) {
        stop();
        // The RESET strobe takes effect one clock cycle after the write
        // (section 30.5.1); wait it out before re-arming CTRLB.
        while (busy()) {}
    }
    crcscan.CTRLB.write(.{ .SRC = source });
    // NMIEN promotes a failure to an NMI, which only software reset clears
    // (section 30.3.2.1 "Checksum", page 454).
    // https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=454
    crcscan.CTRLA.write(.{
        .ENABLE = 1,
        .NMIEN = @intFromBool(non_maskable),
        .RESET = 0,
    });
}

/// Halt any scan in progress.
///
/// Section 30.5.1: writing CTRLA.ENABLE to 0 "has no effect" while enabled;
/// halting requires the RESET strobe. The strobe also clears CTRLA, CTRLB and
/// STATUS, so restarting afterwards needs a fresh `start()`.
pub fn stop() void {
    crcscan.CTRLA.write(.{ .ENABLE = 1, .NMIEN = 0, .RESET = 1 });
}

/// Restart the scan from the beginning.
///
/// The RESET strobe wipes CTRLB along with everything else (section 30.5.1:
/// RESET clears "the entire CRCSCAN"), so this re-arms the last requested
/// source rather than resuming mid-scan.
pub fn restart() void {
    // Capture SRC before RESET wipes CTRLB (section 30.5.1).
    const source = crcscan.CTRLB.read().SRC;
    var bits = crcscan.CTRLA.read();
    bits.RESET = 1;
    bits.ENABLE = 1;
    crcscan.CTRLA.write(bits);
    // Section 30.5.2: CTRLB is not writable while busy; wait like `start`.
    while (busy()) {}
    crcscan.CTRLB.write(.{ .SRC = source });
}

/// True while a CRC scan is running (STATUS.BUSY).
pub fn busy() bool {
    return crcscan.STATUS.read().BUSY != 0;
}

/// True when the last completed scan matched.
///
/// Only meaningful once `busy()` is false; it reads as 0 while a scan is in
/// flight, so polling it without checking `busy()` looks like a failure.
pub fn ok() bool {
    return crcscan.STATUS.read().OK != 0;
}

/// Run one scan to completion and report whether flash matched.
pub fn verify_blocking(source: Source) bool {
    start(source, false);
    while (busy()) {}
    const result = ok();
    stop();
    return result;
}
