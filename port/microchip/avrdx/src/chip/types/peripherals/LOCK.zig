const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const LOCK = extern struct {
    /// Lock Key select
    pub const LOCK_KEY = enum(u32) {
        /// No locks
        NOLOCK = 0x5cc5c55c,
        /// Read and write lock
        RWLOCK = 0xa33a3aa3,
        _,
    };

    /// Lock Key Bits
    /// offset: 0x00
    KEY: mmio.Mmio(packed struct(u32) {
        /// Lock Key
        KEY: LOCK_KEY,
    }),
};
