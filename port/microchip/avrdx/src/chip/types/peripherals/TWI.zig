const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const TWI = extern struct {
    /// Acknowledge Action select
    pub const TWI_ACKACT = enum(u1) {
        /// Send ACK
        ACK = 0x0,
        /// Send NACK
        NACK = 0x1,
    };

    /// Address or Stop select
    pub const TWI_AP = enum(u1) {
        /// A Stop condition generated the interrupt on APIF flag
        STOP = 0x0,
        /// Address detection generated the interrupt on APIF flag
        ADR = 0x1,
    };

    /// Bus State select
    pub const TWI_BUSSTATE = enum(u2) {
        /// Unknown bus state
        UNKNOWN = 0x0,
        /// Bus is idle
        IDLE = 0x1,
        /// This TWI controls the bus
        OWNER = 0x2,
        /// The bus is busy
        BUSY = 0x3,
    };

    /// Debug Run select
    pub const TWI_DBGRUN = enum(u1) {
        /// The peripheral is halted in Break Debug mode and ignores events
        HALT = 0x0,
        /// The peripheral will continue to run in Break Debug mode when the CPU is halted
        RUN = 0x1,
    };

    /// Fast-mode Plus Enable select
    pub const TWI_FMPEN = enum(u1) {
        /// Operating in Standard-mode or Fast-mode
        OFF = 0x0,
        /// Operating in Fast-mode Plus
        ON = 0x1,
    };

    /// Input voltage transition level select
    pub const TWI_INPUTLVL = enum(u1) {
        /// I2C input voltage transition level
        I2C = 0x0,
        /// SMBus 3.0 input voltage transition level
        SMBUS = 0x1,
    };

    /// Command select
    pub const TWI_MCMD = enum(u2) {
        /// No action
        NOACT = 0x0,
        /// Execute Acknowledge Action followed by repeated Start.
        REPSTART = 0x1,
        /// Execute Acknowledge Action followed by a byte read/write operation. Read/write is defined by DIR.
        RECVTRANS = 0x2,
        /// Execute Acknowledge Action followed by issuing a Stop condition.
        STOP = 0x3,
    };

    /// Command select
    pub const TWI_SCMD = enum(u2) {
        /// No Action
        NOACT = 0x0,
        /// Complete transaction
        COMPTRANS = 0x2,
        /// Used in response to an interrupt
        RESPONSE = 0x3,
        _,
    };

    /// SDA Hold Time select
    pub const TWI_SDAHOLD = enum(u2) {
        /// No SDA Hold Delay
        OFF = 0x0,
        /// Short SDA hold time
        @"50NS" = 0x1,
        /// Meets SMBUS 2.0 specification under typical conditions
        @"300NS" = 0x2,
        /// Meets SMBUS 2.0 specificaiton across all corners
        @"500NS" = 0x3,
    };

    /// SDA Setup Time select
    pub const TWI_SDASETUP = enum(u1) {
        /// SDA setup time is four clock cycles
        @"4CYC" = 0x0,
        /// SDA setup time is eight clock cycle
        @"8CYC" = 0x1,
    };

    /// Inactive Bus Time-Out select
    pub const TWI_TIMEOUT = enum(u2) {
        /// Bus time-out disabled. I2C.
        DISABLED = 0x0,
        /// 50us - SMBus
        @"50US" = 0x1,
        /// 100us
        @"100US" = 0x2,
        /// 200us
        @"200US" = 0x3,
    };

    /// Control A
    /// offset: 0x00
    CTRLA: mmio.Mmio(packed struct(u8) {
        reserved1: u1 = 0,
        /// Fast-mode Plus Enable
        FMPEN: TWI_FMPEN,
        /// SDA Hold Time
        SDAHOLD: TWI_SDAHOLD,
        /// SDA Setup Time
        SDASETUP: TWI_SDASETUP,
        reserved6: u1 = 0,
        /// Input voltage transition level
        INPUTLVL: TWI_INPUTLVL,
        padding: u1 = 0,
    }),
    /// Dual Mode Control
    /// offset: 0x01
    DUALCTRL: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Fast-mode Plus Enable
        FMPEN: TWI_FMPEN,
        /// SDA Hold Time
        SDAHOLD: TWI_SDAHOLD,
        reserved6: u2 = 0,
        /// Input voltage transition level
        INPUTLVL: TWI_INPUTLVL,
        padding: u1 = 0,
    }),
    /// Debug Control
    /// offset: 0x02
    DBGCTRL: mmio.Mmio(packed struct(u8) {
        /// Debug Run
        DBGRUN: TWI_DBGRUN,
        padding: u7 = 0,
    }),
    /// Host Control A
    /// offset: 0x03
    MCTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Smart Mode Enable
        SMEN: u1,
        /// Inactive Bus Time-Out
        TIMEOUT: TWI_TIMEOUT,
        /// Quick Command Enable
        QCEN: u1,
        reserved6: u1 = 0,
        /// Write Interrupt Enable
        WIEN: u1,
        /// Read Interrupt Enable
        RIEN: u1,
    }),
    /// Host Control B
    /// offset: 0x04
    MCTRLB: mmio.Mmio(packed struct(u8) {
        /// Command
        MCMD: TWI_MCMD,
        /// Acknowledge Action
        ACKACT: TWI_ACKACT,
        /// Flush
        FLUSH: u1,
        padding: u4 = 0,
    }),
    /// Host STATUS
    /// offset: 0x05
    MSTATUS: mmio.Mmio(packed struct(u8) {
        /// Bus State
        BUSSTATE: TWI_BUSSTATE,
        /// Bus Error
        BUSERR: u1,
        /// Arbitration Lost
        ARBLOST: u1,
        /// Received Acknowledge
        RXACK: u1,
        /// Clock Hold
        CLKHOLD: u1,
        /// Write Interrupt Flag
        WIF: u1,
        /// Read Interrupt Flag
        RIF: u1,
    }),
    /// Host Baud Rate
    /// offset: 0x06
    MBAUD: mmio.Mmio(packed struct(u8) {
        /// Baud Rate
        BAUD: u8,
    }),
    /// Host Address
    /// offset: 0x07
    MADDR: mmio.Mmio(packed struct(u8) {
        /// Address
        ADDR: u8,
    }),
    /// Host Data
    /// offset: 0x08
    MDATA: mmio.Mmio(packed struct(u8) {
        /// Data
        DATA: u8,
    }),
    /// Client Control A
    /// offset: 0x09
    SCTRLA: mmio.Mmio(packed struct(u8) {
        /// Enable
        ENABLE: u1,
        /// Smart Mode Enable
        SMEN: u1,
        /// Address Recognition Mode
        PMEN: u1,
        reserved5: u2 = 0,
        /// Stop Interrupt Enable
        PIEN: u1,
        /// Address or Stop Interrupt Enable
        APIEN: u1,
        /// Data Interrupt Enable
        DIEN: u1,
    }),
    /// Client Control B
    /// offset: 0x0a
    SCTRLB: mmio.Mmio(packed struct(u8) {
        /// Command
        SCMD: TWI_SCMD,
        /// Acknowledge Action
        ACKACT: TWI_ACKACT,
        padding: u5 = 0,
    }),
    /// Client Status
    /// offset: 0x0b
    SSTATUS: mmio.Mmio(packed struct(u8) {
        /// Address or Stop
        AP: TWI_AP,
        /// Read/Write Direction
        DIR: u1,
        /// Bus Error
        BUSERR: u1,
        /// Collision
        COLL: u1,
        /// Received Acknowledge
        RXACK: u1,
        /// Clock Hold
        CLKHOLD: u1,
        /// Address or Stop Interrupt Flag
        APIF: u1,
        /// Data Interrupt Flag
        DIF: u1,
    }),
    /// Client Address
    /// offset: 0x0c
    SADDR: mmio.Mmio(packed struct(u8) {
        /// Address
        ADDR: u8,
    }),
    /// Client Data
    /// offset: 0x0d
    SDATA: mmio.Mmio(packed struct(u8) {
        /// Data
        DATA: u8,
    }),
    /// Client Address Mask
    /// offset: 0x0e
    SADDRMASK: mmio.Mmio(packed struct(u8) {
        /// Address Mask Enable
        ADDREN: u1,
        /// Address Mask
        ADDRMASK: u7,
    }),
};
