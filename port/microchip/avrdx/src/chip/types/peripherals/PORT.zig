const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const PORT = extern struct {
    /// Input/Sense Configuration select
    pub const PORT_ISC = enum(u3) {
        /// Interrupt disabled but input buffer enabled
        INTDISABLE = 0x0,
        /// Sense Both Edges
        BOTHEDGES = 0x1,
        /// Sense Rising Edge
        RISING = 0x2,
        /// Sense Falling Edge
        FALLING = 0x3,
        /// Digital Input Buffer disabled
        INPUT_DISABLE = 0x4,
        /// Sense low Level
        LEVEL = 0x5,
        _,
    };

    /// Data Direction
    /// offset: 0x00
    DIR: u8,
    /// Data Direction Set
    /// offset: 0x01
    DIRSET: u8,
    /// Data Direction Clear
    /// offset: 0x02
    DIRCLR: u8,
    /// Data Direction Toggle
    /// offset: 0x03
    DIRTGL: u8,
    /// Output Value
    /// offset: 0x04
    OUT: u8,
    /// Output Value Set
    /// offset: 0x05
    OUTSET: u8,
    /// Output Value Clear
    /// offset: 0x06
    OUTCLR: u8,
    /// Output Value Toggle
    /// offset: 0x07
    OUTTGL: u8,
    /// Input Value
    /// offset: 0x08
    IN: u8,
    /// Interrupt Flags
    /// offset: 0x09
    INTFLAGS: mmio.Mmio(packed struct(u8) {
        /// Pin Interrupt Flag
        INT: u8,
    }),
    /// Port Control
    /// offset: 0x0a
    PORTCTRL: mmio.Mmio(packed struct(u8) {
        /// Slew Rate Limit Enable
        SRL: u1,
        padding: u7 = 0,
    }),
    /// Pin Control Config
    /// offset: 0x0b
    PINCONFIG: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin Control Update
    /// offset: 0x0c
    PINCTRLUPD: mmio.Mmio(packed struct(u8) {
        /// Pin control update mask
        PINCTRLUPD: u8,
    }),
    /// Pin Control Set
    /// offset: 0x0d
    PINCTRLSET: mmio.Mmio(packed struct(u8) {
        /// Pin control set mask
        PINCTRLSET: u8,
    }),
    /// Pin Control Clear
    /// offset: 0x0e
    PINCTRLCLR: mmio.Mmio(packed struct(u8) {
        /// Pin control clear mask
        PINCTRLCLR: u8,
    }),
    /// offset: 0x0f
    reserved15: [1]u8,
    /// Pin 0 Control
    /// offset: 0x10
    PIN0CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 1 Control
    /// offset: 0x11
    PIN1CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 2 Control
    /// offset: 0x12
    PIN2CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 3 Control
    /// offset: 0x13
    PIN3CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 4 Control
    /// offset: 0x14
    PIN4CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 5 Control
    /// offset: 0x15
    PIN5CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 6 Control
    /// offset: 0x16
    PIN6CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
    /// Pin 7 Control
    /// offset: 0x17
    PIN7CTRL: mmio.Mmio(packed struct(u8) {
        /// Input/Sense Configuration
        ISC: PORT_ISC,
        /// Pullup enable
        PULLUPEN: u1,
        reserved6: u2 = 0,
        /// Input level select
        INLVL: u1,
        /// Inverted I/O Enable
        INVEN: u1,
    }),
};
