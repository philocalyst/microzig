//! Raw register map for the AVR32DD20.
//!
//! Every address here is transcribed from the AVR32DD20 device pack (ATDF from
//! Microchip.AVR-Dx_DFP): peripheral bases come from the `<instance>`
//! `register-group` offsets, and the per-register offsets from each module's
//! `register-group`. Only peripherals that are actually present on the 20-pin
//! AVR32DD20 are listed -- there is no PORTB or PORTE on this part, and PORTC
//! starts at PC1, PORTD at PD4, PORTF at PF6.
//!
//! Citations in this package refer to the AVR16/32DD14/20 data sheet,
//! Microchip DS40002413. Page anchors are direct links:
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf
//!
//! The peripheral address map is section 9.1, page 63.

pub inline fn mem8(address: u16) *volatile u8 {
    return @ptrFromInt(address);
}

pub inline fn mem16(address: u16) *volatile u16 {
    return @ptrFromInt(address);
}

pub inline fn mem32(address: u16) *volatile u32 {
    return @ptrFromInt(address);
}

pub inline fn read(address: u16) u8 {
    return mem8(address).*;
}

pub inline fn write(address: u16, value: u8) void {
    mem8(address).* = value;
}

pub inline fn set_bits(address: u16, mask: u8) void {
    write(address, read(address) | mask);
}

pub inline fn clear_bits(address: u16, mask: u8) void {
    write(address, read(address) & ~mask);
}

pub inline fn toggle_bits(address: u16, mask: u8) void {
    write(address, read(address) ^ mask);
}

pub inline fn bit(index: u3) u8 {
    return @as(u8, 1) << index;
}

/// Data-space layout, from the AVR32DD20 ATDF `data` address space.
pub const memory = struct {
    pub const io_base: u16 = 0x0000;
    pub const io_size: u16 = 0x103F;

    pub const lockbits_base: u16 = 0x1040;
    pub const fuses_base: u16 = 0x1050;
    pub const user_row_base: u16 = 0x1080;
    pub const user_row_size: u16 = 0x20;
    pub const signatures_base: u16 = 0x1100;
    pub const prod_signatures_base: u16 = 0x1103;

    pub const eeprom_base: u16 = 0x1400;
    pub const eeprom_size: u16 = 0x100;
    pub const eeprom_page_size: u16 = 1;

    pub const sram_base: u16 = 0x7000;
    pub const sram_size: u17 = 0x1000;

    /// Flash is mapped into the data space one 32 KiB section at a time; on
    /// AVR32DD20 the whole 32 KiB device flash fits in a single section.
    pub const mapped_progmem_base: u16 = 0x8000;
    pub const mapped_progmem_size: u17 = 0x8000;

    pub const flash_size: u17 = 0x8000;
    pub const flash_page_size: u16 = 0x200;
};

// -- Virtual ports ----------------------------------------------------------
// VPORT registers live in the low I/O space, so single-bit accesses compile to
// the atomic SBI/CBI instructions. Note the gap where VPORTB would be: the
// AVR32DD20 has no PORTB.
// DS40002413 section 18.3.2.5 "Virtual Ports", page 167.

pub const vporta = struct {
    pub const base: u16 = 0x0000;
    pub const dir = base + 0x0;
    pub const out = base + 0x1;
    pub const in = base + 0x2;
    pub const intflags = base + 0x3;
};

pub const vportc = struct {
    pub const base: u16 = 0x0008;
    pub const dir = base + 0x0;
    pub const out = base + 0x1;
    pub const in = base + 0x2;
    pub const intflags = base + 0x3;
};

pub const vportd = struct {
    pub const base: u16 = 0x000C;
    pub const dir = base + 0x0;
    pub const out = base + 0x1;
    pub const in = base + 0x2;
    pub const intflags = base + 0x3;
};

pub const vportf = struct {
    pub const base: u16 = 0x0014;
    pub const dir = base + 0x0;
    pub const out = base + 0x1;
    pub const in = base + 0x2;
    pub const intflags = base + 0x3;
};

// -- Core -------------------------------------------------------------------

pub const gpr = struct {
    pub const base: u16 = 0x001C;
    pub const gpr0 = base + 0x0;
    pub const gpr1 = base + 0x1;
    pub const gpr2 = base + 0x2;
    pub const gpr3 = base + 0x3;
};

pub const cpu = struct {
    pub const base: u16 = 0x0030;
    pub const ccp = base + 0x4;
    pub const sp = base + 0xD;
    pub const sreg = base + 0xF;

    /// CPU.CCP signatures. DS40002413 section 7.4.6, page 37.
    pub const signature_spm: u8 = 0x9D;
    pub const signature_ioreg: u8 = 0xD8;
};

pub const rstctrl = struct {
    pub const base: u16 = 0x0040;
    pub const rstfr = base + 0x0;
    pub const swrr = base + 0x1;

    pub const porf = 0;
    pub const borf = 1;
    pub const extrf = 2;
    pub const wdrf = 3;
    pub const swrf = 4;
    pub const updirf = 5;
    pub const swrst = 0;
};

pub const slpctrl = struct {
    pub const base: u16 = 0x0050;
    pub const ctrla = base + 0x0;
    pub const vregctrl = base + 0x1;

    pub const sen = 0;
};

pub const clkctrl = struct {
    pub const base: u16 = 0x0060;
    pub const mclkctrla = base + 0x00;
    pub const mclkctrlb = base + 0x01;
    pub const mclkctrlc = base + 0x02;
    pub const mclkintctrl = base + 0x03;
    pub const mclkintflags = base + 0x04;
    pub const mclkstatus = base + 0x05;
    pub const oschfctrla = base + 0x08;
    pub const oschftune = base + 0x09;
    pub const pllctrla = base + 0x10;
    pub const osc32kctrla = base + 0x18;
    pub const xosc32kctrla = base + 0x1C;
    pub const xoschfctrla = base + 0x20;

    pub const clkout = 7;
    pub const pen = 0;
    pub const cfden = 0;

    // MCLKSTATUS
    pub const sosc = 0;
    pub const oschfs = 1;
    pub const osc32ks = 2;
    pub const xosc32ks = 3;
    pub const exts = 4;
    pub const plls = 5;

    pub const autotune = 0;
    pub const runstdby = 7;
    pub const xosc_enable = 0;
};

pub const bod = struct {
    pub const base: u16 = 0x00A0;
    pub const ctrla = base + 0x0;
    pub const ctrlb = base + 0x1;
    pub const vlmctrla = base + 0x8;
    pub const intctrl = base + 0x9;
    pub const intflags = base + 0xA;
    pub const status = base + 0xB;

    pub const vlmif = 0;
    pub const vlms = 0;
};

pub const vref = struct {
    pub const base: u16 = 0x00B0;
    pub const adc0ref = base + 0x0;
    pub const dac0ref = base + 0x2;
    pub const acref = base + 0x4;

    pub const alwayson = 7;
};

pub const mvio = struct {
    pub const base: u16 = 0x00C0;
    pub const intctrl = base + 0x0;
    pub const intflags = base + 0x1;
    pub const status = base + 0x2;

    pub const vddio2ie = 0;
    pub const vddio2if = 0;
    pub const vddio2s = 0;
};

pub const wdt = struct {
    pub const base: u16 = 0x0100;
    pub const ctrla = base + 0x0;
    pub const status = base + 0x1;

    pub const syncbusy = 0;
    pub const lock = 7;
};

pub const cpuint = struct {
    pub const base: u16 = 0x0110;
    pub const ctrla = base + 0x0;
    pub const status = base + 0x1;
    pub const lvl0pri = base + 0x2;
    pub const lvl1vec = base + 0x3;

    pub const lvl0rr = 0;
    pub const cvt = 5;
    pub const ivsel = 6;

    pub const lvl0ex = 0;
    pub const lvl1ex = 1;
    pub const nmiex = 7;
};

pub const crcscan = struct {
    pub const base: u16 = 0x0120;
    pub const ctrla = base + 0x0;
    pub const ctrlb = base + 0x1;
    pub const status = base + 0x2;

    pub const enable = 0;
    pub const nmien = 1;
    pub const reset = 7;

    pub const busy = 0;
    pub const ok = 1;
};

pub const rtc = struct {
    pub const base: u16 = 0x0140;
    pub const ctrla = base + 0x00;
    pub const status = base + 0x01;
    pub const intctrl = base + 0x02;
    pub const intflags = base + 0x03;
    pub const temp = base + 0x04;
    pub const dbgctrl = base + 0x05;
    pub const calib = base + 0x06;
    pub const clksel = base + 0x07;
    pub const cnt = base + 0x08;
    pub const per = base + 0x0A;
    pub const cmp = base + 0x0C;
    pub const pitctrla = base + 0x10;
    pub const pitstatus = base + 0x11;
    pub const pitintctrl = base + 0x12;
    pub const pitintflags = base + 0x13;
    pub const pitdbgctrl = base + 0x15;

    pub const rtcen = 0;
    pub const corren = 2;
    pub const runstdby = 7;

    // STATUS
    pub const ctrlabusy = 0;
    pub const cntbusy = 1;
    pub const perbusy = 2;
    pub const cmpbusy = 3;

    // INTCTRL / INTFLAGS
    pub const ovf = 0;
    pub const cmp_bit = 1;

    // PIT
    pub const piten = 0;
    pub const pi = 0;
    pub const ctrlbusy = 0;
};

pub const ccl = struct {
    pub const base: u16 = 0x01C0;
    pub const ctrla = base + 0x00;
    pub const seqctrl0 = base + 0x01;
    pub const seqctrl1 = base + 0x02;
    pub const intctrl0 = base + 0x05;
    pub const intflags = base + 0x07;
    /// LUTnCTRLA/B/C and TRUTHn repeat every four bytes from 0x08.
    pub const lut0ctrla = base + 0x08;
    pub const lut_stride: u16 = 4;
    /// Four LUTs exist in silicon. Only LUT0..LUT2 can reach a pin on the
    /// 20-pin package (LUT0 out PA3/PA6, LUT1 out PC3, LUT2 out PD6); LUT3 is
    /// usable as an internal-only term.
    pub const lut_count = 4;

    pub const enable = 0;
    pub const runstdby = 6;
    // LUTnCTRLA
    pub const lut_enable = 0;
    pub const lut_output_enable = 6;
    pub const lut_edge_detect = 7;
};

pub const evsys = struct {
    pub const base: u16 = 0x0200;
    pub const sweventa = base + 0x00;
    pub const sweventb = base + 0x01;

    /// CHANNEL0..CHANNEL5 are contiguous from 0x10.
    pub const channel0 = base + 0x10;
    pub const channel_count = 6;

    /// Event users. These are *not* a dense index space, so they are named
    /// individually rather than derived from a base + user id.
    pub const user = struct {
        pub const ccl_lut0_a = base + 0x20;
        pub const ccl_lut0_b = base + 0x21;
        pub const ccl_lut1_a = base + 0x22;
        pub const ccl_lut1_b = base + 0x23;
        pub const ccl_lut2_a = base + 0x24;
        pub const ccl_lut2_b = base + 0x25;
        pub const ccl_lut3_a = base + 0x26;
        pub const ccl_lut3_b = base + 0x27;
        pub const adc0_start = base + 0x28;
        pub const evouta = base + 0x29;
        pub const evoutc = base + 0x2A;
        pub const evoutd = base + 0x2B;
        pub const evoutf = base + 0x2C;
        pub const usart0_irda = base + 0x2D;
        pub const usart1_irda = base + 0x2E;
        pub const tca0_cnt_a = base + 0x2F;
        pub const tca0_cnt_b = base + 0x30;
        pub const tcb0_capt = base + 0x31;
        pub const tcb0_count = base + 0x32;
        pub const tcb1_capt = base + 0x33;
        pub const tcb1_count = base + 0x34;
        pub const tcd0_input_a = base + 0x37;
        pub const tcd0_input_b = base + 0x38;
    };
};

// -- Ports ------------------------------------------------------------------
// Full PORT register blocks. Beyond DIR/OUT/IN these expose the atomic
// SET/CLR/TGL aliases and, new on AVR Dx, the PINCONFIG + PINCTRLUPD/SET/CLR
// trio that applies one pin configuration to several pins in a single write.
// DS40002413 section 18 "PORT - I/O Pin Configuration", page 163.

pub const port_offsets = struct {
    pub const dir = 0x00;
    pub const dirset = 0x01;
    pub const dirclr = 0x02;
    pub const dirtgl = 0x03;
    pub const out = 0x04;
    pub const outset = 0x05;
    pub const outclr = 0x06;
    pub const outtgl = 0x07;
    pub const in = 0x08;
    pub const intflags = 0x09;
    pub const portctrl = 0x0A;
    pub const pinconfig = 0x0B;
    pub const pinctrlupd = 0x0C;
    pub const pinctrlset = 0x0D;
    pub const pinctrlclr = 0x0E;
    /// PIN0CTRL..PIN7CTRL are contiguous from 0x10.
    pub const pin0ctrl = 0x10;
};

pub const porta_base: u16 = 0x0400;
pub const portc_base: u16 = 0x0440;
pub const portd_base: u16 = 0x0460;
pub const portf_base: u16 = 0x04A0;

/// PORTn.PINnCTRL / PORTn.PINCONFIG bit positions.
pub const port_bits = struct {
    pub const pullupen = 3;
    pub const inlvl = 6;
    pub const inven = 7;
    pub const srl = 0;
};

pub const portmux = struct {
    pub const base: u16 = 0x05E0;
    pub const evsysroutea = base + 0x00;
    pub const cclroutea = base + 0x01;
    pub const usartroutea = base + 0x02;
    pub const spiroutea = base + 0x05;
    pub const twiroutea = base + 0x06;
    pub const tcaroutea = base + 0x07;
    pub const tcbroutea = base + 0x08;
    pub const tcdroutea = base + 0x09;
};

// -- Analog -----------------------------------------------------------------

pub const adc0 = struct {
    pub const base: u16 = 0x0600;
    pub const ctrla = base + 0x00;
    pub const ctrlb = base + 0x01;
    pub const ctrlc = base + 0x02;
    pub const ctrld = base + 0x03;
    pub const ctrle = base + 0x04;
    pub const sampctrl = base + 0x05;
    pub const muxpos = base + 0x08;
    pub const muxneg = base + 0x09;
    pub const command = base + 0x0A;
    pub const evctrl = base + 0x0B;
    pub const intctrl = base + 0x0C;
    pub const intflags = base + 0x0D;
    pub const dbgctrl = base + 0x0E;
    pub const temp = base + 0x0F;
    pub const res = base + 0x10;
    pub const winlt = base + 0x12;
    pub const winht = base + 0x14;

    // CTRLA
    pub const enable = 0;
    pub const freerun = 1;
    pub const leftadj = 4;
    pub const runstby = 7;

    // COMMAND
    pub const stconv = 0;
    pub const spconv = 1;

    // INTCTRL / INTFLAGS
    pub const resrdy = 0;
    pub const wcmp = 1;

    // EVCTRL
    pub const startei = 0;
};

pub const ac0 = struct {
    pub const base: u16 = 0x0680;
    pub const ctrla = base + 0x0;
    pub const muxctrl = base + 0x2;
    pub const dacref = base + 0x5;
    pub const intctrl = base + 0x6;
    pub const status = base + 0x7;

    pub const enable = 0;
    pub const outen = 6;
    pub const runstdby = 7;
    pub const cmp = 0;
    pub const state = 4;
    pub const invert = 7;
};

pub const dac0 = struct {
    pub const base: u16 = 0x06A0;
    pub const ctrla = base + 0x0;
    pub const data = base + 0x2;

    pub const enable = 0;
    pub const outen = 6;
    pub const runstdby = 7;
};

pub const zcd3 = struct {
    pub const base: u16 = 0x06D8;
    pub const ctrla = base + 0x0;
    pub const intctrl = base + 0x2;
    pub const status = base + 0x3;

    // CTRLA
    pub const enable = 0;
    pub const invert = 3;
    pub const outen = 6;
    pub const runstdby = 7;
    // STATUS
    pub const cross_if = 0;
    pub const state = 4;
};

// -- Serial -----------------------------------------------------------------

pub const usart_offsets = struct {
    pub const rxdatal = 0x00;
    pub const rxdatah = 0x01;
    pub const txdatal = 0x02;
    pub const txdatah = 0x03;
    pub const status = 0x04;
    pub const ctrla = 0x05;
    pub const ctrlb = 0x06;
    pub const ctrlc = 0x07;
    pub const baud = 0x08;
    pub const ctrld = 0x0A;
    pub const dbgctrl = 0x0B;
    pub const evctrl = 0x0C;
    pub const txplctrl = 0x0D;
    pub const rxplctrl = 0x0E;
};

pub const usart0_base: u16 = 0x0800;
pub const usart1_base: u16 = 0x0820;

pub const usart_bits = struct {
    // STATUS
    pub const wfb = 0;
    pub const bdf = 1;
    pub const isfif = 3;
    pub const rxsif = 4;
    pub const dreif = 5;
    pub const txcif = 6;
    pub const rxcif = 7;

    // CTRLA
    pub const rs485 = 0;
    pub const abeie = 2;
    pub const lbme = 3;
    pub const rxsie = 4;
    pub const dreie = 5;
    pub const txcie = 6;
    pub const rxcie = 7;

    // CTRLB
    pub const mpcm = 0;
    pub const rxmode = 1; // two bits: 1..2
    pub const sfden = 4;
    pub const odme = 3;
    pub const txen = 6;
    pub const rxen = 7;
};

pub const twi0 = struct {
    pub const base: u16 = 0x0900;
    pub const ctrla = base + 0x0;
    pub const dualctrl = base + 0x1;
    pub const dbgctrl = base + 0x2;
    pub const mctrla = base + 0x3;
    pub const mctrlb = base + 0x4;
    pub const mstatus = base + 0x5;
    pub const mbaud = base + 0x6;
    pub const maddr = base + 0x7;
    pub const mdata = base + 0x8;
    pub const sctrla = base + 0x9;
    pub const sctrlb = base + 0xA;
    pub const sstatus = base + 0xB;
    pub const saddr = base + 0xC;
    pub const sdata = base + 0xD;
    pub const saddrmask = base + 0xE;

    // MCTRLA
    pub const menable = 0;
    pub const smen = 1;
    pub const wien = 6;
    pub const rien = 7;

    // MSTATUS
    pub const busstate = 0; // two bits: 0..1
    pub const buserr = 2;
    pub const arblost = 3;
    pub const rxack = 4;
    pub const clkhold = 5;
    pub const wif = 6;
    pub const rif = 7;
};

pub const spi0 = struct {
    pub const base: u16 = 0x0940;
    pub const ctrla = base + 0x0;
    pub const ctrlb = base + 0x1;
    pub const intctrl = base + 0x2;
    pub const intflags = base + 0x3;
    pub const data = base + 0x4;

    // CTRLA
    pub const enable = 0;
    pub const master = 5;
    pub const dord = 6;
    pub const clk2x = 4;

    // CTRLB
    pub const ssd = 2;
    pub const bufwr = 6;
    pub const bufen = 7;

    // INTFLAGS (buffered mode names differ; these are the normal-mode bits)
    pub const wrcol = 6;
    pub const spi_if = 7;
};

// -- Timers -----------------------------------------------------------------

pub const tca0 = struct {
    pub const base: u16 = 0x0A00;

    /// Register block when TCA0.SINGLE (SPLITM = 0) is selected.
    pub const single = struct {
        pub const ctrla = base + 0x00;
        pub const ctrlb = base + 0x01;
        pub const ctrlc = base + 0x02;
        pub const ctrld = base + 0x03;
        pub const ctrleclr = base + 0x04;
        pub const ctrleset = base + 0x05;
        pub const ctrlfclr = base + 0x06;
        pub const ctrlfset = base + 0x07;
        pub const evctrl = base + 0x09;
        pub const intctrl = base + 0x0A;
        pub const intflags = base + 0x0B;
        pub const dbgctrl = base + 0x0E;
        pub const temp = base + 0x0F;
        pub const cnt = base + 0x20;
        pub const per = base + 0x26;
        pub const cmp0 = base + 0x28;
        pub const cmp1 = base + 0x2A;
        pub const cmp2 = base + 0x2C;
        pub const perbuf = base + 0x36;
        pub const cmp0buf = base + 0x38;
        pub const cmp1buf = base + 0x3A;
        pub const cmp2buf = base + 0x3C;
    };

    /// Register block when TCA0.SPLIT (SPLITM = 1) is selected: two independent
    /// 8-bit timers sharing the prescaler.
    pub const split = struct {
        pub const ctrla = base + 0x00;
        pub const ctrlb = base + 0x01;
        pub const ctrlc = base + 0x02;
        pub const ctrld = base + 0x03;
        pub const ctrleclr = base + 0x04;
        pub const ctrleset = base + 0x05;
        pub const intctrl = base + 0x0A;
        pub const intflags = base + 0x0B;
        pub const dbgctrl = base + 0x0E;
        pub const lcnt = base + 0x20;
        pub const hcnt = base + 0x21;
        pub const lper = base + 0x26;
        pub const hper = base + 0x27;
        pub const lcmp0 = base + 0x28;
        pub const hcmp0 = base + 0x29;
        pub const lcmp1 = base + 0x2A;
        pub const hcmp1 = base + 0x2B;
        pub const lcmp2 = base + 0x2C;
        pub const hcmp2 = base + 0x2D;
    };

    // CTRLA
    pub const enable = 0;
    pub const runstdby = 7;

    // CTRLB (single mode)
    pub const alupd = 3;
    pub const cmp0en = 4;
    pub const cmp1en = 5;
    pub const cmp2en = 6;

    // CTRLD
    pub const splitm = 0;

    // INTCTRL / INTFLAGS (single mode)
    pub const ovf = 0;
    pub const cmp0 = 4;
    pub const cmp1 = 5;
    pub const cmp2 = 6;
};

pub const tcb_offsets = struct {
    pub const ctrla = 0x0;
    pub const ctrlb = 0x1;
    pub const evctrl = 0x4;
    pub const intctrl = 0x5;
    pub const intflags = 0x6;
    pub const status = 0x7;
    pub const dbgctrl = 0x8;
    pub const temp = 0x9;
    pub const cnt = 0xA;
    pub const ccmp = 0xC;
};

pub const tcb0_base: u16 = 0x0B00;
pub const tcb1_base: u16 = 0x0B10;

pub const tcb_bits = struct {
    // CTRLA
    pub const enable = 0;
    pub const synupd = 4;
    pub const cascade = 5;
    pub const runstdby = 6;

    // CTRLB
    pub const ccmpen = 4;
    pub const ccmpinit = 5;
    pub const asyncen = 6;

    // INTCTRL / INTFLAGS
    pub const capt = 0;
    pub const ovf = 1;

    // STATUS
    pub const run = 0;
};

pub const tcd0 = struct {
    pub const base: u16 = 0x0B80;
    pub const ctrla = base + 0x00;
    pub const ctrlb = base + 0x01;
    pub const ctrlc = base + 0x02;
    pub const ctrld = base + 0x03;
    pub const ctrle = base + 0x04;
    pub const evctrla = base + 0x08;
    pub const evctrlb = base + 0x09;
    pub const intctrl = base + 0x0C;
    pub const intflags = base + 0x0D;
    pub const status = base + 0x0E;
    pub const inputctrla = base + 0x10;
    pub const inputctrlb = base + 0x11;
    pub const faultctrl = base + 0x12;
    pub const dlyctrl = base + 0x14;
    pub const dlyval = base + 0x15;
    pub const ditctrl = base + 0x18;
    pub const ditval = base + 0x19;
    pub const dbgctrl = base + 0x1E;
    pub const capturea = base + 0x22;
    pub const captureb = base + 0x24;
    pub const cmpaset = base + 0x28;
    pub const cmpaclr = base + 0x2A;
    pub const cmpbset = base + 0x2C;
    pub const cmpbclr = base + 0x2E;

    // CTRLA
    pub const enable = 0;

    // CTRLE
    pub const synceoc = 0;
    pub const sync = 1;
    pub const restart = 2;
    pub const scapturea = 3;
    pub const scaptureb = 4;
    pub const disable = 7;

    // STATUS
    pub const enrdy = 0;
    pub const cmdrdy = 1;
    pub const pwmacta = 6;
    pub const pwmactb = 7;

    // INTCTRL / INTFLAGS
    pub const ovf = 0;
    pub const triga = 2;
    pub const trigb = 3;
};

// -- Non-volatile memory ----------------------------------------------------

pub const nvmctrl = struct {
    pub const base: u16 = 0x1000;
    pub const ctrla = base + 0x0;
    pub const ctrlb = base + 0x1;
    pub const status = base + 0x2;
    pub const intctrl = base + 0x3;
    pub const intflags = base + 0x4;
    pub const data = base + 0x6;
    pub const addr = base + 0x8;

    // STATUS
    pub const fbusy = 0;
    pub const eebusy = 1;
    pub const error_mask: u8 = 0x70;

    // INTCTRL / INTFLAGS
    pub const eeready = 0;

    // CTRLB
    pub const appcodewp = 0;
    pub const bootrp = 1;
    pub const appdatawp = 2;
    pub const flmap_mask: u8 = 0x30;
    pub const flmap_shift = 4;
    pub const flmaplock = 7;
};

pub const lockbits = struct {
    pub const base: u16 = 0x1040;
    pub const key = base + 0x0;
};

pub const fuse = struct {
    pub const base: u16 = 0x1050;
    pub const wdtcfg = base + 0x0;
    pub const bodcfg = base + 0x1;
    pub const osccfg = base + 0x2;
    pub const syscfg0 = base + 0x5;
    pub const syscfg1 = base + 0x6;
    pub const codesize = base + 0x7;
    pub const bootsize = base + 0x8;
};

pub const userrow = struct {
    pub const base: u16 = 0x1080;
    pub const size: u16 = 0x20;
};

pub const sigrow = struct {
    pub const base: u16 = 0x1100;
    pub const deviceid0 = base + 0x00;
    pub const deviceid1 = base + 0x01;
    pub const deviceid2 = base + 0x02;
    pub const tempsense0 = base + 0x04;
    pub const tempsense1 = base + 0x06;
    pub const sernum0 = base + 0x10;
    pub const sernum_len = 16;

    /// Device signature of the AVR32DD20, from the ATDF SIGNATURES property
    /// group. Handy for a boot-time sanity check.
    pub const expected_device_id: [3]u8 = .{ 0x1E, 0x95, 0x3A };
};

pub const syscfg = struct {
    pub const base: u16 = 0x0F00;
    pub const revid = base + 0x1;
    pub const ocdmctrl = base + 0x4;
    pub const ocdmstatus = base + 0x5;
};
