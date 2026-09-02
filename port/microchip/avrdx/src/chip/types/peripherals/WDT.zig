const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const WDT = extern struct {
    /// Period select
    pub const WDT_PERIOD = enum(u4) {
        /// Off
        OFF = 0x0,
        /// 8 cycles (8ms)
        @"8CLK" = 0x1,
        /// 16 cycles (16ms)
        @"16CLK" = 0x2,
        /// 32 cycles (32ms)
        @"32CLK" = 0x3,
        /// 64 cycles (64ms)
        @"64CLK" = 0x4,
        /// 128 cycles (0.128s)
        @"128CLK" = 0x5,
        /// 256 cycles (0.256s)
        @"256CLK" = 0x6,
        /// 512 cycles (0.512s)
        @"512CLK" = 0x7,
        /// 1K cycles (1.0s)
        @"1KCLK" = 0x8,
        /// 2K cycles (2.0s)
        @"2KCLK" = 0x9,
        /// 4K cycles (4.1s)
        @"4KCLK" = 0xa,
        /// 8K cycles (8.2s)
        @"8KCLK" = 0xb,
        _,
    };

    /// Window select
    pub const WDT_WINDOW = enum(u4) {
        /// Off
        OFF = 0x0,
        /// 8 cycles (8ms)
        @"8CLK" = 0x1,
        /// 16 cycles (16ms)
        @"16CLK" = 0x2,
        /// 32 cycles (32ms)
        @"32CLK" = 0x3,
        /// 64 cycles (64ms)
        @"64CLK" = 0x4,
        /// 128 cycles (0.128s)
        @"128CLK" = 0x5,
        /// 256 cycles (0.256s)
        @"256CLK" = 0x6,
        /// 512 cycles (0.512s)
        @"512CLK" = 0x7,
        /// 1K cycles (1.0s)
        @"1KCLK" = 0x8,
        /// 2K cycles (2.0s)
        @"2KCLK" = 0x9,
        /// 4K cycles (4.1s)
        @"4KCLK" = 0xa,
        /// 8K cycles (8.2s)
        @"8KCLK" = 0xb,
        _,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Period
        PERIOD: WDT_PERIOD,
        /// Window
        WINDOW: WDT_WINDOW,
    }),
    /// Status
    /// offset: 0x01
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Syncronization busy
        SYNCBUSY: u1,
        reserved7: u6 = 0,
        /// Lock enable
        LOCK: u1,
    }),
};
