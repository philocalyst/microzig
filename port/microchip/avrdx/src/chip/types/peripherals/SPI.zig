const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const SPI = extern struct {
    /// SPI Mode select
    pub const SPI_MODE = enum(u2) {
        /// SPI Mode 0
        @"0" = 0x0,
        /// SPI Mode 1
        @"1" = 0x1,
        /// SPI Mode 2
        @"2" = 0x2,
        /// SPI Mode 3
        @"3" = 0x3,
    };

    /// Prescaler select
    pub const SPI_PRESC = enum(u2) {
        /// CLK_PER / 4
        DIV4 = 0x0,
        /// CLK_PER / 16
        DIV16 = 0x1,
        /// CLK_PER / 64
        DIV64 = 0x2,
        /// CLK_PER / 128
        DIV128 = 0x3,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable Module
        ENABLE: u1,
        /// Prescaler
        PRESC: SPI_PRESC,
        reserved4: u1 = 0,
        /// Enable Double Speed
        CLK2X: u1,
        /// Host Operation Enable
        MASTER: u1,
        /// Data Order Setting
        DORD: u1,
        padding: u1 = 0,
    }),
    /// Control B
    /// offset: 0x01
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// SPI Mode
        MODE: SPI_MODE,
        /// SPI Select Disable
        SSD: u1,
        reserved6: u3 = 0,
        /// Buffer Mode Wait for Receive
        BUFWR: u1,
        /// Buffer Mode Enable
        BUFEN: u1,
    }),
    /// Interrupt Control
    /// offset: 0x02
    INTCTRL: mmio.Mmio(packed struct(u8) {
        /// Interrupt Enable
        IE: u1,
        reserved4: u3 = 0,
        /// SPI Select Trigger Interrupt Enable
        SSIE: u1,
        /// Data Register Empty Interrupt Enable
        DREIE: u1,
        /// Transfer Complete Interrupt Enable
        TXCIE: u1,
        /// Receive Complete Interrupt Enable
        RXCIE: u1,
    }),
    /// Interrupt Flags
    /// offset: 0x03
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Buffer Overflow
        BUFOVF: u1,
        reserved4: u3 = 0,
        /// SPI Select Trigger Interrupt Flag
        SSIF: u1,
        /// Data Register Empty Interrupt Flag
        DREIF: u1,
        /// Transfer Complete Interrupt Flag
        TXCIF: u1,
        /// Receive Complete Interrupt Flag
        RXCIF: u1,
    }),
    /// Data
    /// offset: 0x04
    DATA: u8,
};
