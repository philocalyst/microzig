//! BOD - Brown-out Detector, and the Voltage Level Monitor it carries.
//!
//! DS40002413 section 20 "BOD - Brown-out Detector", page 200.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=200
//!
//! The brown-out threshold and the active/sleep modes come from FUSE.BODCFG
//! and are fixed at programming time; CTRLA/CTRLB are read-only reflections of
//! the fuse unless the fuse selected the "controlled by software" mode. The
//! VLM, by contrast, is entirely a run-time feature and is the useful half of
//! this peripheral for most firmware: it warns you *before* VDD reaches the
//! reset threshold.

const microzig = @import("microzig");

const bod = microzig.chip.peripherals.BOD;
const gen = microzig.chip.types.peripherals.BOD;

/// BOD.CTRLB.LVL - the reset threshold, set by FUSE.BODCFG.LVL. Re-exported
/// from the generated layer.
pub const Level = gen.BOD_LVL;

/// BOD.VLMCTRLA.VLMLVL - where the monitor trips, as a margin above the BOD
/// level. Picking 25% above a 2.7V BOD gives a warning at ~3.4V.
pub const MonitorLevel = gen.BOD_VLMLVL;

/// BOD.INTCTRL.VLMCFG - which crossing direction raises the interrupt.
pub const MonitorEdge = gen.BOD_VLMCFG;

/// The configured brown-out reset threshold.
pub fn level() Level {
    return bod.CTRLB.read().LVL;
}

/// Enable the voltage level monitor and its interrupt.
///
/// DS40002413 section 20.3.2 "Interrupts", page 202.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=202
///
/// VLMCTRLA is not CCP-protected. Only the SLEEP and SAMPFREQ bits of
/// BOD.CTRLA are (Table 20-2, section 20.3.4, page 202), and this HAL never
/// writes CTRLA, so the BOD needs no CCP window at all.
pub fn enable_monitor(monitor_level: MonitorLevel, edge: MonitorEdge) void {
    bod.VLMCTRLA.write(.{ .VLMLVL = monitor_level });
    bod.INTCTRL.write(.{
        .VLMIE = 1,
        .VLMCFG = edge,
    });
}

/// Disable the voltage-level monitor and its interrupt.
pub fn disable_monitor() void {
    bod.INTCTRL.write(.{ .VLMIE = 0, .VLMCFG = .FALLING });
    bod.VLMCTRLA.write(.{ .VLMLVL = .OFF });
}

/// True when VDD is currently *below* the monitor threshold.
pub fn below_threshold() bool {
    return bod.STATUS.read().VLMS == .BELOW;
}

/// True when the configured VLM crossing was observed.
pub fn monitor_pending() bool {
    return bod.INTFLAGS.read().VLMIF != 0;
}

/// Clear the VLM interrupt flag (write-one-to-clear).
pub fn clear_monitor_flag() void {
    bod.INTFLAGS.write(.{ .VLMIF = 1 });
}
