//! SLPCTRL - Sleep Controller.
//!
//! DS40002413 section 13 "SLPCTRL - Sleep Controller", page 112.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=112

const regs = @import("registers.zig");
const ccp = @import("ccp.zig");

/// SLPCTRL.CTRLA.SMODE.
///
/// DS40002413 section 13.3.3.1 "Sleep Modes", page 113: which peripherals keep
/// running differs sharply between these, most importantly that in power-down
/// only the fully asynchronous wake sources (PIT, pin level/both-edges
/// interrupts, TWI address match, BOD/VLM) remain live.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=113
pub const Mode = enum(u8) {
    /// CPU stopped, all peripherals and interrupts still running.
    idle = 0x0,
    /// Only peripherals with RUNSTDBY set keep their clock.
    standby = 0x1,
    /// Lowest power; almost everything is stopped.
    power_down = 0x2,
};

/// SLPCTRL.VREGCTRL.PMODE - voltage regulator performance mode.
pub const RegulatorMode = enum(u8) {
    /// Regulator follows the sleep mode automatically.
    auto = 0x0,
    /// Regulator stays in full-power mode, trading current for wake-up time.
    full = 0x1,
};

// SLPCTRL's "Configuration Change Protection" subsection (DS40002413 section
// 13.3.5, page 116) protects VREGCTRL and nothing else: Table 13-6 has the one
// row, and CTRLA's register description (section 13.5.1, page 118) reads
// `Property: -`. So the sleep mode and SEN are written plainly, and only
// `set_regulator_mode` below opens a CCP window.

/// Select the sleep mode without arming sleep.
pub fn set_mode(mode: Mode) void {
    regs.write(regs.slpctrl.ctrla, @as(u8, @intFromEnum(mode)) << 1);
}

/// Arm sleep (CTRLA.SEN) so that a `sleep()` actually suspends the CPU.
pub fn enable(mode: Mode) void {
    regs.write(
        regs.slpctrl.ctrla,
        (@as(u8, @intFromEnum(mode)) << 1) | regs.bit(regs.slpctrl.sen),
    );
}

pub fn disable() void {
    const value = regs.read(regs.slpctrl.ctrla) & ~regs.bit(regs.slpctrl.sen);
    regs.write(regs.slpctrl.ctrla, value);
}

/// Execute the SLEEP instruction. Does nothing unless sleep is armed.
pub inline fn sleep() void {
    asm volatile ("sleep");
}

/// Arm the given mode and sleep, leaving sleep armed on wake.
pub fn enter(mode: Mode) void {
    enable(mode);
    sleep();
}

/// Sleep exactly once: arm, sleep, then disarm so a later stray SLEEP cannot
/// suspend the CPU unintentionally.
pub fn enter_once(mode: Mode) void {
    enable(mode);
    sleep();
    disable();
}

/// Select the voltage regulator's performance mode.
///
/// DS40002413 section 13.3.2 "Voltage Regulator Configuration", page 113.
/// VREGCTRL is the peripheral's only CCP-protected register, IOREG key
/// (Table 13-6, page 116).
pub fn set_regulator_mode(mode: RegulatorMode) void {
    ccp.write_io(regs.slpctrl.vregctrl, @intFromEnum(mode));
}
