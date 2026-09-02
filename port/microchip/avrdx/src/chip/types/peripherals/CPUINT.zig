const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const CPUINT = extern struct {
    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Round-robin Scheduling Enable
        LVL0RR: u1,
        reserved5: u4 = 0,
        /// Compact Vector Table
        CVT: u1,
        /// Interrupt Vector Select
        IVSEL: u1,
        padding: u1 = 0,
    }),
    /// Status
    /// offset: 0x01
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Level 0 Interrupt Executing
        LVL0EX: u1,
        /// Level 1 Interrupt Executing
        LVL1EX: u1,
        reserved7: u5 = 0,
        /// Non-maskable Interrupt Executing
        NMIEX: u1,
    }),
    /// Interrupt Level 0 Priority
    /// offset: 0x02
    LVL0PRI: mmio.Mmio(packed struct(u8) {
        /// Interrupt Level Priority
        LVL0PRI: u8,
    }),
    /// Interrupt Level 1 Priority Vector
    /// offset: 0x03
    LVL1VEC: mmio.Mmio(packed struct(u8) {
        /// Interrupt Vector with High Priority
        LVL1VEC: u8,
    }),
};
