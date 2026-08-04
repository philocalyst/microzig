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

const regs = @import("registers.zig");

/// BOD.CTRLB.LVL - the reset threshold, set by FUSE.BODCFG.LVL.
pub const Level = enum(u8) {
    v1_9 = 0x0,
    v2_45 = 0x1,
    v2_7 = 0x2,
    v2_85 = 0x3,
    _,

    pub fn millivolts(l: Level) ?u16 {
        return switch (l) {
            .v1_9 => 1900,
            .v2_45 => 2450,
            .v2_7 => 2700,
            .v2_85 => 2850,
            _ => null,
        };
    }
};

/// BOD.VLMCTRLA.VLMLVL - where the monitor trips, as a margin above the BOD
/// level. Picking 25% above a 2.7V BOD gives a warning at ~3.4V.
pub const MonitorLevel = enum(u8) {
    off = 0x0,
    above5 = 0x1,
    above15 = 0x2,
    above25 = 0x3,
};

/// BOD.INTCTRL.VLMCFG - which crossing direction raises the interrupt.
pub const MonitorEdge = enum(u8) {
    /// VDD fell below the threshold: the "we are about to brown out" warning.
    falling = 0x0,
    /// VDD rose back above the threshold.
    rising = 0x1,
    both = 0x2,
};

/// The configured brown-out reset threshold.
pub fn level() Level {
    return @enumFromInt(regs.read(regs.bod.ctrlb) & 0x07);
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
    regs.write(regs.bod.vlmctrla, @intFromEnum(monitor_level));
    regs.write(
        regs.bod.intctrl,
        regs.bit(0) | (@as(u8, @intFromEnum(edge)) << 1),
    );
}

pub fn disable_monitor() void {
    regs.write(regs.bod.intctrl, 0);
    regs.write(regs.bod.vlmctrla, @intFromEnum(MonitorLevel.off));
}

/// True when VDD is currently *below* the monitor threshold.
pub fn below_threshold() bool {
    return (regs.read(regs.bod.status) & regs.bit(regs.bod.vlms)) != 0;
}

pub fn monitor_pending() bool {
    return (regs.read(regs.bod.intflags) & regs.bit(regs.bod.vlmif)) != 0;
}

pub fn clear_monitor_flag() void {
    regs.write(regs.bod.intflags, regs.bit(regs.bod.vlmif));
}
