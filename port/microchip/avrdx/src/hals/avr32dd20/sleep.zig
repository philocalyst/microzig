//! SLPCTRL - Sleep Controller.
//!
//! DS40002413 section 13 "SLPCTRL - Sleep Controller", page 112.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=112

const microzig = @import("microzig");
const ccp = @import("ccp.zig");

const slpctrl = microzig.chip.peripherals.SLPCTRL;
const gen = microzig.chip.types.peripherals.SLPCTRL;

const VregctrlBits = @TypeOf(slpctrl.VREGCTRL).underlying_type;

/// SLPCTRL.CTRLA.SMODE. Friendly tags; encodings from generated SLPCTRL_SMODE.
///
/// DS40002413 section 13.3.3.1 "Sleep Modes", page 113: which peripherals keep
/// running differs sharply between these, most importantly that in power-down
/// only the fully asynchronous wake sources (PIT, pin level/both-edges
/// interrupts, TWI address match, BOD/VLM) remain live.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=113
pub const Mode = enum(u2) {
    idle = @intFromEnum(gen.SLPCTRL_SMODE.IDLE),
    standby = @intFromEnum(gen.SLPCTRL_SMODE.STDBY),
    power_down = @intFromEnum(gen.SLPCTRL_SMODE.PDOWN),

    fn to_field(mode: Mode) gen.SLPCTRL_SMODE {
        return @enumFromInt(@intFromEnum(mode));
    }
};

/// SLPCTRL.VREGCTRL.PMODE - voltage regulator performance mode.
pub const RegulatorMode = enum(u1) {
    auto = @intFromEnum(gen.SLPCTRL_PMODE.AUTO),
    full = @intFromEnum(gen.SLPCTRL_PMODE.FULL),

    fn to_field(mode: RegulatorMode) gen.SLPCTRL_PMODE {
        return @enumFromInt(@intFromEnum(mode));
    }
};

// SLPCTRL Configuration Change Protection (DS40002413 section 13.3.5, page 116)
// protects VREGCTRL and nothing else: Table 13-6 has the one row, and CTRLA
// reads Property: -. Sleep mode and SEN are written plainly; only
// set_regulator_mode opens a CCP window.

/// Select the sleep mode without arming sleep.
pub fn set_mode(mode: Mode) void {
    slpctrl.CTRLA.modify(.{ .SMODE = mode.to_field() });
}

/// Arm sleep (CTRLA.SEN) so that a sleep() actually suspends the CPU.
pub fn enable(mode: Mode) void {
    slpctrl.CTRLA.write(.{
        .SEN = 1,
        .SMODE = mode.to_field(),
    });
}

/// Clear SLPCTRL.CTRLA.SEN so the next sleep instruction executes
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
