//! CPUINT - CPU Interrupt Controller.
//!
//! DS40002413 section 15 "CPUINT - CPU Interrupt Controller", page 129.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=129

const microzig = @import("microzig");
const ccp = @import("ccp.zig");

const cpuint = microzig.chip.peripherals.CPUINT;
const cpu = microzig.chip.peripherals.CPU;

pub inline fn enable_interrupts() void {
    asm volatile ("sei");
}

pub inline fn disable_interrupts() void {
    asm volatile ("cli");
}

/// Run `body` with interrupts masked, restoring the previous state afterwards.
///
/// Saving SREG rather than unconditionally re-enabling means this nests, and
/// that calling it from inside an interrupt handler does not accidentally turn
/// interrupts back on.
pub fn critical_section(body: anytype) void {
    const sreg = cpu.SREG.read();
    disable_interrupts();
    defer cpu.SREG.write(sreg);
    body();
}

/// Promote one vector to level 1, above every level 0 interrupt.
///
/// Only one vector can hold this at a time. `vector_number` is the device's
/// interrupt vector index.
///
/// DS40002413 section 15.3.2.4.2 "High-Priority Interrupt", page 132.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=132
pub fn set_high_priority_vector(vector_number: u8) void {
    cpuint.LVL1VEC.write(.{ .LVL1VEC = vector_number });
}

/// Remove the level-1 assignment; every vector drops back to level 0.
pub fn clear_high_priority_vector() void {
    cpuint.LVL1VEC.write(.{ .LVL1VEC = 0 });
}

/// Enable round-robin scheduling among level 0 interrupts, so a low-numbered
/// vector cannot starve the rest.
///
/// DS40002413 section 15.3.2.4.3 "Normal-Priority Interrupts", page 132.
/// Only CTRLA.IVSEL and CTRLA.CVT are CCP-protected; LVL0RR is written
/// plainly (section 15.3.4, Table 15-3, page 135 lists the protected subset).
pub fn set_round_robin(enable: bool) void {
    cpuint.CTRLA.modify(.{ .LVL0RR = @intFromBool(enable) });
}

/// In round-robin mode, set the vector that goes last in the current round.
pub fn set_round_robin_base(vector_number: u8) void {
    cpuint.LVL0PRI.write(.{ .LVL0PRI = vector_number });
}

/// Collapse the vector table to a single shared entry.
///
/// DS40002413 section 15.3.2.2 "Interrupt Vector Locations", page 130: with
/// CVT set there is one interrupt vector for all sources and the handler must
/// dispatch on the peripheral flags itself. It saves a lot of flash on a
/// 32 KiB part, at the cost of dispatch latency.
///
/// IVSEL and CVT are the two CCP-protected bits of CTRLA (Table 15-3).
pub fn set_compact_vector_table(enable: bool) void {
    const addr = comptime @intFromPtr(&cpuint.CTRLA);
    ccp.write_io(addr, ctrl_byte(.{ .cvt = enable }));
}

/// Move the vector table to the start of the boot section (CTRLA.IVSEL,
/// CCP-protected per Table 15-3).
pub fn set_vectors_in_boot_section(enable: bool) void {
    const addr = comptime @intFromPtr(&cpuint.CTRLA);
    ccp.write_io(addr, ctrl_byte(.{ .ivsel = enable }));
}

fn ctrl_byte(opts: struct { ivsel: bool = false, cvt: bool = false }) u8 {
    // Read-modify-write through the generated type so only IVSEL/CVT change;
    // they are the two CCP-protected bits (Table 15-3).
    const CtrlABits = @TypeOf(cpuint.CTRLA.read());
    var bits: CtrlABits = cpuint.CTRLA.read();
    bits.IVSEL = @intFromBool(opts.ivsel);
    bits.CVT = @intFromBool(opts.cvt);
    return @bitCast(bits);
}

/// True while a level 1 interrupt is being serviced.
pub fn level1_executing() bool {
    return cpuint.STATUS.read().LVL1EX != 0;
}

/// True while a non-maskable interrupt is being serviced.
pub fn nmi_executing() bool {
    return cpuint.STATUS.read().NMIEX != 0;
}
