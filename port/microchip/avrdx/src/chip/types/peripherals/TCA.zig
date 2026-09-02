const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const TCA = extern union {
    pub const Mode = enum {
        SINGLE,
        SPLIT,
    };

    pub fn get_mode(self: *volatile @This()) Mode {
        {
            const value = self.SINGLE.CTRLD.read().SPLITM;
            switch (value) {
                0,
                => return .SINGLE,
                else => {},
            }
        }
        {
            const value = self.SPLIT.CTRLD.read().SPLITM;
            switch (value) {
                1,
                => return .SPLIT,
                else => {},
            }
        }

        unreachable;
    }

    /// Clock Selection
    pub const TCA_SINGLE_CLKSEL = enum(u3) {
        /// CLK_PER
        DIV1 = 0x0,
        /// CLK_PER / 2
        DIV2 = 0x1,
        /// CLK_PER / 4
        DIV4 = 0x2,
        /// CLK_PER / 8
        DIV8 = 0x3,
        /// CLK_PER / 16
        DIV16 = 0x4,
        /// CLK_PER / 64
        DIV64 = 0x5,
        /// CLK_PER / 256
        DIV256 = 0x6,
        /// CLK_PER / 1024
        DIV1024 = 0x7,
    };

    /// Command select
    pub const TCA_SINGLE_CMD = enum(u2) {
        /// No Command
        NONE = 0x0,
        /// Force Update
        UPDATE = 0x1,
        /// Force Restart
        RESTART = 0x2,
        /// Force Hard Reset
        RESET = 0x3,
    };

    /// Direction select
    pub const TCA_SINGLE_DIR = enum(u1) {
        /// Count up
        UP = 0x0,
        /// Count down
        DOWN = 0x1,
    };

    /// Event Action A select
    pub const TCA_SINGLE_EVACTA = enum(u3) {
        /// Count on positive edge event
        CNT_POSEDGE = 0x0,
        /// Count on any edge event
        CNT_ANYEDGE = 0x1,
        /// Count on prescaled clock while event line is 1.
        CNT_HIGHLVL = 0x2,
        /// Count on prescaled clock. Event controls count direction. Up-count when event line is 0, down-count when event line is 1.
        UPDOWN = 0x3,
        _,
    };

    /// Event Action B select
    pub const TCA_SINGLE_EVACTB = enum(u3) {
        /// No Action
        NONE = 0x0,
        /// Count on prescaled clock. Event controls count direction. Up-count when event line is 0, down-count when event line is 1.
        UPDOWN = 0x3,
        /// Restart counter at positive edge event
        RESTART_POSEDGE = 0x4,
        /// Restart counter on any edge event
        RESTART_ANYEDGE = 0x5,
        /// Restart counter while event line is 1.
        RESTART_HIGHLVL = 0x6,
        _,
    };

    /// Waveform generation mode select
    pub const TCA_SINGLE_WGMODE = enum(u3) {
        /// Normal Mode
        NORMAL = 0x0,
        /// Frequency Generation Mode
        FRQ = 0x1,
        /// Single Slope PWM
        SINGLESLOPE = 0x3,
        /// Dual Slope PWM, overflow on TOP
        DSTOP = 0x5,
        /// Dual Slope PWM, overflow on TOP and BOTTOM
        DSBOTH = 0x6,
        /// Dual Slope PWM, overflow on BOTTOM
        DSBOTTOM = 0x7,
        _,
    };

    /// Clock Selection
    pub const TCA_SPLIT_CLKSEL = enum(u3) {
        /// CLK_PER
        DIV1 = 0x0,
        /// CLK_PER / 2
        DIV2 = 0x1,
        /// CLK_PER / 4
        DIV4 = 0x2,
        /// CLK_PER / 8
        DIV8 = 0x3,
        /// CLK_PER / 16
        DIV16 = 0x4,
        /// CLK_PER / 64
        DIV64 = 0x5,
        /// CLK_PER / 256
        DIV256 = 0x6,
        /// CLK_PER / 1024
        DIV1024 = 0x7,
    };

    /// Command select
    pub const TCA_SPLIT_CMD = enum(u2) {
        /// No Command
        NONE = 0x0,
        /// Force Restart
        RESTART = 0x2,
        /// Force Hard Reset
        RESET = 0x3,
        _,
    };

    /// Command Enable select
    pub const TCA_SPLIT_CMDEN = enum(u2) {
        /// None
        NONE = 0x0,
        /// Both low byte and high byte counter
        BOTH = 0x3,
        _,
    };

    SINGLE: extern struct {
        /// Control A
        /// offset: 0x00
        CTRLA: mmio.Mmio(packed struct(u8) {
            /// Module Enable
            ENABLE: u1,
            /// Clock Selection
            CLKSEL: TCA_SINGLE_CLKSEL,
            reserved7: u3 = 0,
            /// Run in Standby
            RUNSTDBY: u1,
        }),
        /// Control B
        /// offset: 0x01
        CTRLB: mmio.Mmio(packed struct(u8) {
            /// Waveform generation mode
            WGMODE: TCA_SINGLE_WGMODE,
            /// Auto Lock Update
            ALUPD: u1,
            /// Compare 0 Enable
            CMP0EN: u1,
            /// Compare 1 Enable
            CMP1EN: u1,
            /// Compare 2 Enable
            CMP2EN: u1,
            padding: u1 = 0,
        }),
        /// Control C
        /// offset: 0x02
        CTRLC: mmio.Mmio(packed struct(u8) {
            /// Compare 0 Waveform Output Value
            CMP0OV: u1,
            /// Compare 1 Waveform Output Value
            CMP1OV: u1,
            /// Compare 2 Waveform Output Value
            CMP2OV: u1,
            padding: u5 = 0,
        }),
        /// Control D
        /// offset: 0x03
        CTRLD: mmio.Mmio(packed struct(u8) {
            /// Split Mode Enable
            SPLITM: u1,
            padding: u7 = 0,
        }),
        /// Control E Clear
        /// offset: 0x04
        CTRLECLR: mmio.Mmio(packed struct(u8) {
            /// Direction
            DIR: u1,
            /// Lock Update
            LUPD: u1,
            /// Command
            CMD: TCA_SINGLE_CMD,
            padding: u4 = 0,
        }),
        /// Control E Set
        /// offset: 0x05
        CTRLESET: mmio.Mmio(packed struct(u8) {
            /// Direction
            DIR: TCA_SINGLE_DIR,
            /// Lock Update
            LUPD: u1,
            /// Command
            CMD: TCA_SINGLE_CMD,
            padding: u4 = 0,
        }),
        /// Control F Clear
        /// offset: 0x06
        CTRLFCLR: mmio.Mmio(packed struct(u8) {
            /// Period Buffer Valid
            PERBV: u1,
            /// Compare 0 Buffer Valid
            CMP0BV: u1,
            /// Compare 1 Buffer Valid
            CMP1BV: u1,
            /// Compare 2 Buffer Valid
            CMP2BV: u1,
            padding: u4 = 0,
        }),
        /// Control F Set
        /// offset: 0x07
        CTRLFSET: mmio.Mmio(packed struct(u8) {
            /// Period Buffer Valid
            PERBV: u1,
            /// Compare 0 Buffer Valid
            CMP0BV: u1,
            /// Compare 1 Buffer Valid
            CMP1BV: u1,
            /// Compare 2 Buffer Valid
            CMP2BV: u1,
            padding: u4 = 0,
        }),
        /// offset: 0x08
        reserved8: [1]u8,
        /// Event Control
        /// offset: 0x09
        EVCTRL: mmio.Mmio(packed struct(u8) {
            /// Count on Event Input A
            CNTAEI: u1,
            /// Event Action A
            EVACTA: TCA_SINGLE_EVACTA,
            /// Count on Event Input B
            CNTBEI: u1,
            /// Event Action B
            EVACTB: TCA_SINGLE_EVACTB,
        }),
        /// Interrupt Control
        /// offset: 0x0a
        INTCTRL: mmio.Mmio(packed struct(u8) {
            /// Overflow Interrupt
            OVF: u1,
            reserved4: u3 = 0,
            /// Compare 0 Interrupt
            CMP0: u1,
            /// Compare 1 Interrupt
            CMP1: u1,
            /// Compare 2 Interrupt
            CMP2: u1,
            padding: u1 = 0,
        }),
        /// Interrupt Flags
        /// offset: 0x0b
        INTFLAGS: mmio.Mmio(packed struct(u8) {
            /// Overflow Interrupt
            OVF: u1,
            reserved4: u3 = 0,
            /// Compare 0 Interrupt
            CMP0: u1,
            /// Compare 1 Interrupt
            CMP1: u1,
            /// Compare 2 Interrupt
            CMP2: u1,
            padding: u1 = 0,
        }),
        /// offset: 0x0c
        reserved12: [2]u8,
        /// Debug Control
        /// offset: 0x0e
        DBGCTRL: mmio.Mmio(packed struct(u8) {
            /// Debug Run
            DBGRUN: u1,
            padding: u7 = 0,
        }),
        /// Temporary data for 16-bit Access
        /// offset: 0x0f
        TEMP: u8,
        /// offset: 0x10
        reserved16: [16]u8,
        /// Count
        /// offset: 0x20
        CNT: u16,
        /// offset: 0x22
        reserved34: [4]u8,
        /// Period
        /// offset: 0x26
        PER: u16,
        /// Compare 0
        /// offset: 0x28
        CMP0: u16,
        /// Compare 1
        /// offset: 0x2a
        CMP1: u16,
        /// Compare 2
        /// offset: 0x2c
        CMP2: u16,
        /// offset: 0x2e
        reserved46: [8]u8,
        /// Period Buffer
        /// offset: 0x36
        PERBUF: u16,
        /// Compare 0 Buffer
        /// offset: 0x38
        CMP0BUF: u16,
        /// Compare 1 Buffer
        /// offset: 0x3a
        CMP1BUF: u16,
        /// Compare 2 Buffer
        /// offset: 0x3c
        CMP2BUF: u16,
    },
    SPLIT: extern struct {
        /// Control A
        /// offset: 0x00
        CTRLA: mmio.Mmio(packed struct(u8) {
            /// Module Enable
            ENABLE: u1,
            /// Clock Selection
            CLKSEL: TCA_SPLIT_CLKSEL,
            reserved7: u3 = 0,
            /// Run in Standby
            RUNSTDBY: u1,
        }),
        /// Control B
        /// offset: 0x01
        CTRLB: mmio.Mmio(packed struct(u8) {
            /// Low Compare 0 Enable
            LCMP0EN: u1,
            /// Low Compare 1 Enable
            LCMP1EN: u1,
            /// Low Compare 2 Enable
            LCMP2EN: u1,
            reserved4: u1 = 0,
            /// High Compare 0 Enable
            HCMP0EN: u1,
            /// High Compare 1 Enable
            HCMP1EN: u1,
            /// High Compare 2 Enable
            HCMP2EN: u1,
            padding: u1 = 0,
        }),
        /// Control C
        /// offset: 0x02
        CTRLC: mmio.Mmio(packed struct(u8) {
            /// Low Compare 0 Output Value
            LCMP0OV: u1,
            /// Low Compare 1 Output Value
            LCMP1OV: u1,
            /// Low Compare 2 Output Value
            LCMP2OV: u1,
            reserved4: u1 = 0,
            /// High Compare 0 Output Value
            HCMP0OV: u1,
            /// High Compare 1 Output Value
            HCMP1OV: u1,
            /// High Compare 2 Output Value
            HCMP2OV: u1,
            padding: u1 = 0,
        }),
        /// Control D
        /// offset: 0x03
        CTRLD: mmio.Mmio(packed struct(u8) {
            /// Split Mode Enable
            SPLITM: u1,
            padding: u7 = 0,
        }),
        /// Control E Clear
        /// offset: 0x04
        CTRLECLR: mmio.Mmio(packed struct(u8) {
            /// Command Enable
            CMDEN: TCA_SPLIT_CMDEN,
            /// Command
            CMD: TCA_SPLIT_CMD,
            padding: u4 = 0,
        }),
        /// Control E Set
        /// offset: 0x05
        CTRLESET: mmio.Mmio(packed struct(u8) {
            /// Command Enable
            CMDEN: TCA_SPLIT_CMDEN,
            /// Command
            CMD: TCA_SPLIT_CMD,
            padding: u4 = 0,
        }),
        /// offset: 0x06
        reserved6: [4]u8,
        /// Interrupt Control
        /// offset: 0x0a
        INTCTRL: mmio.Mmio(packed struct(u8) {
            /// Low Underflow Interrupt Enable
            LUNF: u1,
            /// High Underflow Interrupt Enable
            HUNF: u1,
            reserved4: u2 = 0,
            /// Low Compare 0 Interrupt Enable
            LCMP0: u1,
            /// Low Compare 1 Interrupt Enable
            LCMP1: u1,
            /// Low Compare 2 Interrupt Enable
            LCMP2: u1,
            padding: u1 = 0,
        }),
        /// Interrupt Flags
        /// offset: 0x0b
        INTFLAGS: mmio.Mmio(packed struct(u8) {
            /// Low Underflow Interrupt Flag
            LUNF: u1,
            /// High Underflow Interrupt Flag
            HUNF: u1,
            reserved4: u2 = 0,
            /// Low Compare 2 Interrupt Flag
            LCMP0: u1,
            /// Low Compare 1 Interrupt Flag
            LCMP1: u1,
            /// Low Compare 0 Interrupt Flag
            LCMP2: u1,
            padding: u1 = 0,
        }),
        /// offset: 0x0c
        reserved12: [2]u8,
        /// Debug Control
        /// offset: 0x0e
        DBGCTRL: mmio.Mmio(packed struct(u8) {
            /// Debug Run
            DBGRUN: u1,
            padding: u7 = 0,
        }),
        /// offset: 0x0f
        reserved15: [17]u8,
        /// Low Count
        /// offset: 0x20
        LCNT: u8,
        /// High Count
        /// offset: 0x21
        HCNT: u8,
        /// offset: 0x22
        reserved34: [4]u8,
        /// Low Period
        /// offset: 0x26
        LPER: u8,
        /// High Period
        /// offset: 0x27
        HPER: u8,
        /// Low Compare
        /// offset: 0x28
        LCMP0: u8,
        /// High Compare
        /// offset: 0x29
        HCMP0: u8,
        /// Low Compare
        /// offset: 0x2a
        LCMP1: u8,
        /// High Compare
        /// offset: 0x2b
        HCMP1: u8,
        /// Low Compare
        /// offset: 0x2c
        LCMP2: u8,
        /// High Compare
        /// offset: 0x2d
        HCMP2: u8,
    },
};
