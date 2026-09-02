const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const USART = extern struct {
    /// Auto Baud Window select
    pub const USART_ABW = enum(u2) {
        /// 18% tolerance
        WDW0 = 0x0,
        /// 15% tolerance
        WDW1 = 0x1,
        /// 21% tolerance
        WDW2 = 0x2,
        /// 25% tolerance
        WDW3 = 0x3,
    };

    /// Communication Mode select
    pub const USART_CMODE = enum(u2) {
        /// Asynchronous Mode
        ASYNCHRONOUS = 0x0,
        /// Synchronous Mode
        SYNCHRONOUS = 0x1,
        /// Infrared Communication
        IRCOM = 0x2,
        /// SPI Host Mode
        MSPI = 0x3,
    };

    /// Character Size select
    pub const USART_NORMAL_CHSIZE = enum(u3) {
        /// Character size: 5 bit
        @"5BIT" = 0x0,
        /// Character size: 6 bit
        @"6BIT" = 0x1,
        /// Character size: 7 bit
        @"7BIT" = 0x2,
        /// Character size: 8 bit
        @"8BIT" = 0x3,
        /// Character size: 9 bit read low byte first
        @"9BITL" = 0x6,
        /// Character size: 9 bit read high byte first
        @"9BITH" = 0x7,
        _,
    };

    /// Parity Mode select
    pub const USART_NORMAL_PMODE = enum(u2) {
        /// No Parity
        DISABLED = 0x0,
        /// Even Parity
        EVEN = 0x2,
        /// Odd Parity
        ODD = 0x3,
        _,
    };

    /// Stop Bit Mode select
    pub const USART_NORMAL_SBMODE = enum(u1) {
        /// 1 stop bit
        @"1BIT" = 0x0,
        /// 2 stop bits
        @"2BIT" = 0x1,
    };

    /// RS485 Mode internal transmitter select
    pub const USART_RS485 = enum(u1) {
        /// RS485 Mode disabled
        DISABLE = 0x0,
        /// RS485 Mode enabled
        ENABLE = 0x1,
    };

    /// Receiver Mode select
    pub const USART_RXMODE = enum(u2) {
        /// Normal mode
        NORMAL = 0x0,
        /// CLK2x mode
        CLK2X = 0x1,
        /// Generic autobaud mode
        GENAUTO = 0x2,
        /// LIN constrained autobaud mode
        LINAUTO = 0x3,
    };

    /// Receive Data Low Byte
    /// offset: 0x00
    RXDATAL: mmio.Mmio(packed struct(u8) {
        /// RX Data
        DATA: u8,
    }),
    /// Receive Data High Byte
    /// offset: 0x01
    RXDATAH: mmio.Mmio(packed struct(u8) {
        /// Receiver Data Register
        DATA8: u1,
        /// Parity Error
        PERR: u1,
        /// Frame Error
        FERR: u1,
        reserved6: u3 = 0,
        /// Buffer Overflow
        BUFOVF: u1,
        /// Receive Complete Interrupt Flag
        RXCIF: u1,
    }),
    /// Transmit Data Low Byte
    /// offset: 0x02
    TXDATAL: mmio.Mmio(packed struct(u8) {
        /// Transmit Data Register
        DATA: u8,
    }),
    /// Transmit Data High Byte
    /// offset: 0x03
    TXDATAH: mmio.Mmio(packed struct(u8) {
        /// Transmit Data Register (CHSIZE=9bit)
        DATA8: u1,
        padding: u7 = 0,
    }),
    /// Status
    /// offset: 0x04
    STATUS: mmio.Mmio(packed struct(u8) {
        /// Wait For Break
        WFB: u1,
        /// Break Detected Flag
        BDF: u1,
        reserved3: u1 = 0,
        /// Inconsistent Sync Field Interrupt Flag
        ISFIF: u1,
        /// Receive Start Interrupt
        RXSIF: u1,
        /// Data Register Empty Flag
        DREIF: u1,
        /// Transmit Interrupt Flag
        TXCIF: u1,
        /// Receive Complete Interrupt Flag
        RXCIF: u1,
    }),
    /// Control A
    /// offset: 0x05
    CTRLA: mmio.Mmio(packed struct(u8) {
        /// RS485 Mode internal transmitter
        RS485: USART_RS485,
        reserved2: u1 = 0,
        /// Auto-baud Error Interrupt Enable
        ABEIE: u1,
        /// Loop-back Mode Enable
        LBME: u1,
        /// Receiver Start Frame Interrupt Enable
        RXSIE: u1,
        /// Data Register Empty Interrupt Enable
        DREIE: u1,
        /// Transmit Complete Interrupt Enable
        TXCIE: u1,
        /// Receive Complete Interrupt Enable
        RXCIE: u1,
    }),
    /// Control B
    /// offset: 0x06
    CTRLB: mmio.Mmio(packed struct(u8) {
        /// Multi-processor Communication Mode
        MPCM: u1,
        /// Receiver Mode
        RXMODE: USART_RXMODE,
        /// Open Drain Mode Enable
        ODME: u1,
        /// Start Frame Detection Enable
        SFDEN: u1,
        reserved6: u1 = 0,
        /// Transmitter Enable
        TXEN: u1,
        /// Reciever enable
        RXEN: u1,
    }),
    /// Control C
    /// offset: 0x07
    CTRLC: mmio.Mmio(packed struct(u8) {
        /// Character Size
        CHSIZE: USART_NORMAL_CHSIZE,
        // skipped overlapping field UCPHA at offset 1 bits
        // skipped overlapping field UDORD at offset 2 bits
        /// Stop Bit Mode
        SBMODE: USART_NORMAL_SBMODE,
        /// Parity Mode
        PMODE: USART_NORMAL_PMODE,
        /// Communication Mode
        CMODE: USART_CMODE,
    }),
    /// Baud Rate
    /// offset: 0x08
    BAUD: u16,
    /// Control D
    /// offset: 0x0a
    CTRLD: mmio.Mmio(packed struct(u8) {
        reserved6: u6 = 0,
        /// Auto Baud Window
        ABW: USART_ABW,
    }),
    /// Debug Control
    /// offset: 0x0b
    DBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Debug Run
        DBGRUN: u1,
        padding: u7 = 0,
    }),
    /// Event Control
    /// offset: 0x0c
    EVCTRL: mmio.Mmio(packed struct(u8) {
        /// IrDA Event Input Enable
        IREI: u1,
        padding: u7 = 0,
    }),
    /// IRCOM Transmitter Pulse Length Control
    /// offset: 0x0d
    TXPLCTRL: mmio.Mmio(packed struct(u8) {
        /// Transmit pulse length
        TXPL: u8,
    }),
    /// IRCOM Receiver Pulse Length Control
    /// offset: 0x0e
    RXPLCTRL: mmio.Mmio(packed struct(u8) {
        /// Receiver Pulse Lenght
        RXPL: u7,
        padding: u1 = 0,
    }),
};
