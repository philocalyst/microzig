//! CPUINT - CPU Interrupt Controller.
//!
//! DS40002413 section 15 "CPUINT - CPU Interrupt Controller", page 129.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=129

const regs = @import("registers.zig");
const ccp = @import("ccp.zig");

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
    const sreg = regs.read(regs.cpu.sreg);
    disable_interrupts();
    defer regs.write(regs.cpu.sreg, sreg);
    body();
}

/// Promote one vector to level 1, above every level 0 interrupt.
///
/// Only one vector can hold this at a time. `vector_number` is the device's
/// interrupt vector index.
///
/// DS40002413 section 15.3.2.4.2 "High-Priority Interrupt", page 132.
pub fn set_high_priority_vector(vector_number: u8) void {
    regs.write(regs.cpuint.lvl1vec, vector_number);
}

pub fn clear_high_priority_vector() void {
    regs.write(regs.cpuint.lvl1vec, 0);
}

/// Enable round-robin scheduling among level 0 interrupts, so a low-numbered
/// vector cannot starve the rest.
///
/// DS40002413 section 15.3.2.4.3 "Normal-Priority Interrupts", page 132.
/// CTRLA is CCP-protected.
pub fn set_round_robin(enable: bool) void {
    const value = if (enable)
        regs.read(regs.cpuint.ctrla) | regs.bit(regs.cpuint.lvl0rr)
    else
        regs.read(regs.cpuint.ctrla) & ~regs.bit(regs.cpuint.lvl0rr);
    ccp.write_io(regs.cpuint.ctrla, value);
}

/// In round-robin mode, set the vector that goes last in the current round.
pub fn set_round_robin_base(vector_number: u8) void {
    regs.write(regs.cpuint.lvl0pri, vector_number);
}

/// Collapse the vector table to a single shared entry.
///
/// DS40002413 section 15.3.2.2 "Interrupt Vector Locations", page 130: with
/// CVT set there is one interrupt vector for all sources and the handler must
/// dispatch on the peripheral flags itself. It saves a lot of flash on a
/// 32 KiB part, at the cost of dispatch latency.
pub fn set_compact_vector_table(enable: bool) void {
    const value = if (enable)
        regs.read(regs.cpuint.ctrla) | regs.bit(regs.cpuint.cvt)
    else
        regs.read(regs.cpuint.ctrla) & ~regs.bit(regs.cpuint.cvt);
    ccp.write_io(regs.cpuint.ctrla, value);
}

/// Move the vector table to the start of the boot section.
pub fn set_vectors_in_boot_section(enable: bool) void {
    const value = if (enable)
        regs.read(regs.cpuint.ctrla) | regs.bit(regs.cpuint.ivsel)
    else
        regs.read(regs.cpuint.ctrla) & ~regs.bit(regs.cpuint.ivsel);
    ccp.write_io(regs.cpuint.ctrla, value);
}

/// True while a level 1 interrupt is being serviced.
pub fn level1_executing() bool {
    return (regs.read(regs.cpuint.status) & regs.bit(regs.cpuint.lvl1ex)) != 0;
}

/// True while a non-maskable interrupt is being serviced.
pub fn nmi_executing() bool {
    return (regs.read(regs.cpuint.status) & regs.bit(regs.cpuint.nmiex)) != 0;
}
