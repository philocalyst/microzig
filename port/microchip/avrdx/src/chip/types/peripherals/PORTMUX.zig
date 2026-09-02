const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const PORTMUX = extern struct {
    /// Event Output A select
    pub const PORTMUX_EVOUTA = enum(u1) {
        /// EVOUTA: PA2
        DEFAULT = 0x0,
        /// EVOUTA: PA7
        ALT1 = 0x1,
    };

    /// Event Output C select
    pub const PORTMUX_EVOUTC = enum(u1) {
        /// EVOUTC: PC2
        DEFAULT = 0x0,
        _,
    };

    /// Event Output D select
    pub const PORTMUX_EVOUTD = enum(u1) {
        /// Not connected to any pins
        DEFAULT = 0x0,
        /// EVOUTD: PD7
        ALT1 = 0x1,
    };

    /// CCL Look-Up Table 0 Signals select
    pub const PORTMUX_LUT0 = enum(u1) {
        /// INn: PA0, PA1, PA2. OUT: PA3.
        DEFAULT = 0x0,
        /// INn: PA0, PA1, PA2. OUT: PA6.
        ALT1 = 0x1,
    };

    /// CCL Look-Up Table 1 Signals select
    pub const PORTMUX_LUT1 = enum(u1) {
        /// INn: -, PC1, PC2 OUT: PC3
        DEFAULT = 0x0,
        /// INn: -, PC1, PC2 OUT: -
        ALT1 = 0x1,
    };

    /// CCL Look-Up Table 2 Signals select
    pub const PORTMUX_LUT2 = enum(u1) {
        /// Not connected to any pins
        DEFAULT = 0x0,
        /// INn: -, -, -. OUT: PD6.
        ALT1 = 0x1,
    };

    /// SPI0 Signals select
    pub const PORTMUX_SPI0 = enum(u3) {
        /// MOSI: PA4, MISO: PA5, SCK: PA6, SS: PA7
        DEFAULT = 0x0,
        /// MOSI: PA0, MISO: PA1, SCK: -, SS: PC1
        ALT3 = 0x3,
        /// MOSI: PD4, MISO: PD5, SCK: PD6, SS: PD7
        ALT4 = 0x4,
        /// MOSI: -, MISO: PC1, SCK: PC2, SS: PC3
        ALT5 = 0x5,
        /// MOSI: PC1, MISO: PC2, SCK: PC3, SS: PF7
        ALT6 = 0x6,
        /// Not connected to any pins. SS set to 1.
        NONE = 0x7,
        _,
    };

    /// TCA0 Signals select
    pub const PORTMUX_TCA0 = enum(u3) {
        /// WOn: PA0, PA1, PA2, PA3, PA4, PA5
        PORTA = 0x0,
        /// WOn: -, PC1, PC2, PC3, -, -
        PORTC = 0x2,
        /// WOn: -, -, -, -, PD4, PD5
        PORTD = 0x3,
        _,
    };

    /// TCB0 Output select
    pub const PORTMUX_TCB0 = enum(u1) {
        /// WO: PA2
        DEFAULT = 0x0,
        _,
    };

    /// TCB1 Output select
    pub const PORTMUX_TCB1 = enum(u1) {
        /// WO: PA3
        DEFAULT = 0x0,
        _,
    };

    /// TCD0 Signals select
    pub const PORTMUX_TCD0 = enum(u3) {
        /// WOx: PA4, PA5, PA6, PA7
        DEFAULT = 0x0,
        /// WOx: PA4, PA5, PD4, PD5
        ALT4 = 0x4,
        _,
    };

    /// TWI0 Signals select
    pub const PORTMUX_TWI0 = enum(u2) {
        /// SDA: PA2, SCL: PA3. Dual mode: SDA: PC2, SCL: PC3.
        DEFAULT = 0x0,
        /// SDA: PA2, SCL: PA3. Dual mode: SDA: -, SCL: -.
        ALT1 = 0x1,
        /// SDA: PC2, SCL: PC3. Dual mode: SDA: -, SCL: -.
        ALT2 = 0x2,
        /// SDA: PA0, SCL: PA1. Dual mode: SDA: PC2, SCL: PC3.
        ALT3 = 0x3,
    };

    /// USART0 Signals select
    pub const PORTMUX_USART0 = enum(u3) {
        /// TxD: PA0, RxD: PA1, XCK: PA2, XDIR: PA3
        DEFAULT = 0x0,
        /// TxD: PA4, RxD: PA5, XCK: PA6, XDIR: PA7
        ALT1 = 0x1,
        /// TxD: PA2, RxD: PA3, XCK: -, XDIR: -
        ALT2 = 0x2,
        /// TxD: PD4, RxD: PD5, XCK: PD6, XDIR: PD7
        ALT3 = 0x3,
        /// TxD: PC1, RxD: PC2, XCK: PC3, XDIR: -
        ALT4 = 0x4,
        /// Not connected to any pins
        NONE = 0x5,
        _,
    };

    /// USART1 Signals select
    pub const PORTMUX_USART1 = enum(u2) {
        /// TxD: -, RxD: PC1, XCK: PC2, XDIR: PC3
        DEFAULT = 0x0,
        /// TxD: PD6, RxD: PD7, XCK: -, XDIR: -
        ALT2 = 0x2,
        /// Not connected to any pins
        NONE = 0x3,
        _,
    };

    /// EVSYS route A
    /// offset: 0x00
    EVSYSROUTEA: mmio.Mmio(packed struct(u8) {
        /// Event Output A
        EVOUTA: PORTMUX_EVOUTA,
        reserved2: u1 = 0,
        /// Event Output C
        EVOUTC: PORTMUX_EVOUTC,
        /// Event Output D
        EVOUTD: PORTMUX_EVOUTD,
        padding: u4 = 0,
    }),
    /// CCL route A
    /// offset: 0x01
    CCLROUTEA: mmio.Mmio(packed struct(u8) {
        /// CCL Look-Up Table 0 Signals
        LUT0: PORTMUX_LUT0,
        /// CCL Look-Up Table 1 Signals
        LUT1: PORTMUX_LUT1,
        /// CCL Look-Up Table 2 Signals
        LUT2: PORTMUX_LUT2,
        padding: u5 = 0,
    }),
    /// USART route A
    /// offset: 0x02
    USARTROUTEA: mmio.Mmio(packed struct(u8) {
        /// USART0 Signals
        USART0: PORTMUX_USART0,
        /// USART1 Signals
        USART1: PORTMUX_USART1,
        padding: u3 = 0,
    }),
    /// offset: 0x03
    reserved3: [2]u8,
    /// SPI route A
    /// offset: 0x05
    SPIROUTEA: mmio.Mmio(packed struct(u8) {
        /// SPI0 Signals
        SPI0: PORTMUX_SPI0,
        padding: u5 = 0,
    }),
    /// TWI route A
    /// offset: 0x06
    TWIROUTEA: mmio.Mmio(packed struct(u8) {
        /// TWI0 Signals
        TWI0: PORTMUX_TWI0,
        padding: u6 = 0,
    }),
    /// TCA route A
    /// offset: 0x07
    TCAROUTEA: mmio.Mmio(packed struct(u8) {
        /// TCA0 Signals
        TCA0: PORTMUX_TCA0,
        padding: u5 = 0,
    }),
    /// TCB route A
    /// offset: 0x08
    TCBROUTEA: mmio.Mmio(packed struct(u8) {
        /// TCB0 Output
        TCB0: PORTMUX_TCB0,
        /// TCB1 Output
        TCB1: PORTMUX_TCB1,
        padding: u6 = 0,
    }),
    /// TCD route A
    /// offset: 0x09
    TCDROUTEA: mmio.Mmio(packed struct(u8) {
        /// TCD0 Signals
        TCD0: PORTMUX_TCD0,
        padding: u5 = 0,
    }),
};
