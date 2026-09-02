const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const CPU = extern struct {
    /// CCP signature select
    pub const CPU_CCP = enum(u8) {
        /// SPM Instruction Protection
        SPM = 0x9d,
        /// IO Register Protection
        IOREG = 0xd8,
        _,
    };

    /// offset: 0x00
    reserved0: [4]u8,
    /// Configuration Change Protection
    /// offset: 0x04
    CCP: mmio.Mmio(packed struct(u8) {
        /// CCP signature
        CCP: CPU_CCP,
    }),
    /// offset: 0x05
    reserved5: [8]u8,
    /// Stack Pointer
    /// offset: 0x0d
    SP: u16,
    /// Status Register
    /// offset: 0x0f
    SREG: mmio.Mmio(packed struct(u8) {
        /// Carry Flag
        C: u1,
        /// Zero Flag
        Z: u1,
        /// Negative Flag
        N: u1,
        /// Two's Complement Overflow Flag
        V: u1,
        /// N Exclusive Or V Flag
        S: u1,
        /// Half Carry Flag
        H: u1,
        /// Transfer Bit
        T: u1,
        /// Global Interrupt Enable Flag
        I: u1,
    }),
};
