const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const FUSE = extern struct {
    /// BOD Operation in Active Mode select
    pub const FUSE_ACTIVE = enum(u2) {
        /// BOD disabled
        DISABLE = 0x0,
        /// BOD enabled in continuous mode
        ENABLE = 0x1,
        /// BOD enabled in sampled mode
        SAMPLE = 0x2,
        /// BOD enabled in continuous mode. Execution is halted at wake-up until BOD is running.
        ENABLEWAIT = 0x3,
    };

    /// Frequency Select
    pub const FUSE_CLKSEL = enum(u3) {
        /// 1-32MHz internal oscillator
        OSCHF = 0x0,
        /// 32.768kHz internal oscillator
        OSC32K = 0x1,
        _,
    };

    /// CRC Select
    pub const FUSE_CRCSEL = enum(u1) {
        /// Enable CRC16
        CRC16 = 0x0,
        /// Enable CRC32
        CRC32 = 0x1,
    };

    /// CRC Source select
    pub const FUSE_CRCSRC = enum(u2) {
        /// CRC of full Flash (boot, application code and application data)
        FLASH = 0x0,
        /// CRC of boot section
        BOOT = 0x1,
        /// CRC of application code and boot sections
        BOOTAPP = 0x2,
        /// No CRC
        NOCRC = 0x3,
    };

    /// BOD Level select
    pub const FUSE_LVL = enum(u3) {
        /// 1.9V
        BODLEVEL0 = 0x0,
        /// 2.45V
        BODLEVEL1 = 0x1,
        /// 2.7V
        BODLEVEL2 = 0x2,
        /// 2.85V
        BODLEVEL3 = 0x3,
        _,
    };

    /// MVIO System Configuration select
    pub const FUSE_MVSYSCFG = enum(u2) {
        /// Device used in a dual supply configuration
        DUAL = 0x1,
        /// Device used in a single supply configuration
        SINGLE = 0x2,
        _,
    };

    /// Watchdog Timeout Period select
    pub const FUSE_PERIOD = enum(u4) {
        /// Watch-Dog timer Off
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
        /// 4K cycles (4.0s)
        @"4KCLK" = 0xa,
        /// 8K cycles (8.0s)
        @"8KCLK" = 0xb,
        _,
    };

    /// Reset Pin Configuration select
    pub const FUSE_RSTPINCFG = enum(u1) {
        /// GPIO mode
        GPIO = 0x0,
        /// Reset mode
        RST = 0x1,
    };

    /// BOD Sample Frequency select
    pub const FUSE_SAMPFREQ = enum(u1) {
        /// Sample frequency is 128 Hz
        @"128Hz" = 0x0,
        /// Sample frequency is 32 Hz
        @"32Hz" = 0x1,
    };

    /// BOD Operation in Sleep Mode select
    pub const FUSE_SLEEP = enum(u2) {
        /// BOD disabled
        DISABLE = 0x0,
        /// BOD enabled in continuous mode
        ENABLE = 0x1,
        /// BOD enabled in sampled mode
        SAMPLE = 0x2,
        _,
    };

    /// Startup Time select
    pub const FUSE_SUT = enum(u3) {
        /// 0 ms
        @"0MS" = 0x0,
        /// 1 ms
        @"1MS" = 0x1,
        /// 2 ms
        @"2MS" = 0x2,
        /// 4 ms
        @"4MS" = 0x3,
        /// 8 ms
        @"8MS" = 0x4,
        /// 16 ms
        @"16MS" = 0x5,
        /// 32 ms
        @"32MS" = 0x6,
        /// 64 ms
        @"64MS" = 0x7,
    };

    /// UPDI Pin Configuration select
    pub const FUSE_UPDIPINCFG = enum(u1) {
        /// GPIO Mode
        GPIO = 0x0,
        /// UPDI Mode
        UPDI = 0x1,
    };

    /// Watchdog Window Timeout Period select
    pub const FUSE_WINDOW = enum(u4) {
        /// Window mode off
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
        /// 4K cycles (4.0s)
        @"4KCLK" = 0xa,
        /// 8K cycles (8.0s)
        @"8KCLK" = 0xb,
        _,
    };

    /// Watchdog Configuration
    /// offset: 0x00
    WDTCFG: mmio.Mmio(packed struct(u8) {
        /// Watchdog Timeout Period
        PERIOD: FUSE_PERIOD,
        /// Watchdog Window Timeout Period
        WINDOW: FUSE_WINDOW,
    }),
    /// BOD Configuration
    /// offset: 0x01
    BODCFG: mmio.Mmio(packed struct(u8) {
        /// BOD Operation in Sleep Mode
        SLEEP: FUSE_SLEEP,
        /// BOD Operation in Active Mode
        ACTIVE: FUSE_ACTIVE,
        /// BOD Sample Frequency
        SAMPFREQ: FUSE_SAMPFREQ,
        /// BOD Level
        LVL: FUSE_LVL,
    }),
    /// Oscillator Configuration
    /// offset: 0x02
    OSCCFG: mmio.Mmio(packed struct(u8) {
        /// Frequency Select
        CLKSEL: FUSE_CLKSEL,
        padding: u5 = 0,
    }),
    /// offset: 0x03
    reserved3: [2]u8,
    /// System Configuration 0
    /// offset: 0x05
    SYSCFG0: mmio.Mmio(packed struct(u8) {
        /// EEPROM Save
        EESAVE: u1,
        reserved3: u2 = 0,
        /// Reset Pin Configuration
        RSTPINCFG: FUSE_RSTPINCFG,
        /// UPDI Pin Configuration
        UPDIPINCFG: FUSE_UPDIPINCFG,
        /// CRC Select
        CRCSEL: FUSE_CRCSEL,
        /// CRC Source
        CRCSRC: FUSE_CRCSRC,
    }),
    /// System Configuration 1
    /// offset: 0x06
    SYSCFG1: mmio.Mmio(packed struct(u8) {
        /// Startup Time
        SUT: FUSE_SUT,
        /// MVIO System Configuration
        MVSYSCFG: FUSE_MVSYSCFG,
        padding: u3 = 0,
    }),
    /// Code Section Size
    /// offset: 0x07
    CODESIZE: u8,
    /// Boot Section Size
    /// offset: 0x08
    BOOTSIZE: u8,
};
