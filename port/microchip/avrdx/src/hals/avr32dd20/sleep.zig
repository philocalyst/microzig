//! SLPCTRL - Sleep Controller.
//!
//! DS40002413 section 13 "SLPCTRL - Sleep Controller", page 112.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=112

const microzig = @import("microzig");
const ccp = @import("ccp.zig");

const slpctrl = microzig.chip.peripherals.SLPCTRL;
const gen = microzig.chip.types.peripherals.SLPCTRL;

const CtrlABits = @TypeOf(slpctrl.CTRLA).underlying_type;
const VregctrlBits = @TypeOf(slpctrl.VREGCTRL).underlying_type;

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

    fn to_field(mode: Mode) gen.SLPCTRL_SMODE {
        return switch (mode) {
            .idle => .IDLE,
            .standby => .STDBY,
            .power_down => .PDOWN,
        };
    }
};

/// SLPCTRL.VREGCTRL.PMODE - voltage regulator performance mode.
pub const RegulatorMode = enum(u1) {
    /// Regulator follows the sleep mode automatically.
    auto = 0x0,
    /// Regulator stays in full-power mode, trading current for wake-up time.
    full = 0x1,

    fn to_field(mode: RegulatorMode) gen.SLPCTRL_PMODE {
        return switch (mode) {
            .auto => .AUTO,
            .full => .FULL,
        };
    }
};

// SLPCTRL's "Configuration Change Protection" subsection (DS40002413 section
// 13.3.5, page 116) protects VREGCTRL and nothing else: Table 13-6 has the one
// row, and CTRLA's register description (section 13.5.1, page 118) reads
// `Property: -`. So the sleep mode and SEN are written plainly, and only
// `set_regulator_mode` below opens a CCP window.

/// Select the sleep mode without arming sleep.
pub fn set_mode(mode: Mode) void {
    slpctrl.CTRLA.modify(.{ .SMODE = mode.to_field() });
}

/// Arm sleep (CTRLA.SEN) so that a `sleep()` actually suspends the CPU.
pub fn enable(mode: Mode) void {
    slpctrl.CTRLA.write(.{
        .SEN = 1,
        .SMODE = mode.to_field(),
    });
}

/// Clear SLPCTRL.CTRLA.SEN so the next `sleep_instruction` executes
/// as a normal idle wait instead of the configured sleep mode.
pub fn disable() void {
    var bits = slpctrl.CTRLA.read();
    bits.SEN = 0;
    slpctrl.CTRLA.write(bits);
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
    const addr = comptime @intFromPtr(&slpctrl.VREGCTRL);
    ccp.write_io(addr, @bitCast(VregctrlBits{
        .PMODE = mode.to_field(),
        // HTLLEN has no default in the generated type; 0 keeps the
        // high-temperature leakage feature off, matching the reset state.
        .HTLLEN = @fromBackingInt(@intCast(0)),
    }));
}
