//! Configuration Change Protection.
//!
//! A handful of registers on this part refuse ordinary stores: CPU.CCP must be
//! written with the matching key first, and the protected write has to land
//! within the next four instructions. Both key flavours live here so that
//! callers never open a CCP window by hand.
//!
//! The two failure modes are not symmetric. A plain store to a protected
//! register is silently *dropped* -- the peripheral simply keeps its old
//! configuration and nothing reports an error. A CCP-guarded store to a
//! register that is not protected, on the other hand, behaves exactly like a
//! plain store; the open window just goes unused, at the cost of one extra
//! `sts` and four instructions of deferred interrupts.
//!
//! The protected set is closed and enumerated. Each peripheral chapter carries
//! a "Configuration Change Protection" subsection whose table lists that
//! peripheral's protected registers and the key each one needs; every such
//! table in DS40002413B is reproduced below. Register descriptions agree
//! independently: a protected register's `Property:` line reads "Configuration
//! Change Protection", an unprotected one reads `-`.
//!
//! | Register                     | Key   | Section | Table | Page |
//! |------------------------------|-------|---------|-------|------|
//! | NVMCTRL.CTRLA                | SPM   | 11.3.6  | 11-7  | 79   |
//! | NVMCTRL.CTRLB                | IOREG | 11.3.6  | 11-7  | 79   |
//! | CLKCTRL.MCLKCTRLA            | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.MCLKCTRLB            | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.MCLKCTRLC            | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.MCLKINTCTRL          | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.OSCHFCTRLA           | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.PLLCTRLA             | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.OSC32KCTRLA          | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.XOSC32KCTRLA         | IOREG | 12.3.9  | 12-1  | 96   |
//! | CLKCTRL.XOSCHFCTRLA          | IOREG | 12.3.9  | 12-1  | 96   |
//! | SLPCTRL.VREGCTRL             | IOREG | 13.3.5  | 13-6  | 116  |
//! | RSTCTRL.SWRR                 | IOREG | 14.3.4  | 14-2  | 125  |
//! | CPUINT.CTRLA, IVSEL+CVT only | IOREG | 15.3.4  | 15-3  | 135  |
//! | BOD.CTRLA, SLEEP+SAMPFREQ    | IOREG | 20.3.4  | 20-2  | 202  |
//! | WDT.CTRLA                    | IOREG | 22.3.7  | 22-1  | 218  |
//! | WDT.STATUS, LOCK bit only    | IOREG | 22.3.7  | 22-1  | 218  |
//! | TCDn.FAULTCTRL               | IOREG | 25.3.8  | 25-11 | 321  |
//!
//! Nothing else on this part is protected. Three near misses are worth naming,
//! because each sits next to a register that *is* protected and so invites an
//! unnecessary guard: CLKCTRL.OSCHFTUNE (12.5.8, page 105) is absent from Table
//! 12-1 and reads `Property: -`; SLPCTRL.CTRLA (13.5.1, page 118) is likewise
//! unprotected even though its sibling VREGCTRL is; and BOD.VLMCTRLA (20.5.3,
//! page 206) is unprotected even though two bits of BOD.CTRLA are. The ADC
//! chapter states the case outright -- section 33.3.10 is "Not applicable".

const microzig = @import("microzig");

/// Data-space address of CPU.CCP (`0x0034`, from the generated register layer).
pub const ccp_address: u16 = @intFromPtr(&microzig.chip.peripherals.CPU.CCP);

/// CPU.CCP signatures from the generated layer (ATDF CPU_CCP).
/// Values: SPM=0x9D, IOREG=0xD8. DS40002413 section 7.4.6, page 37.
pub const Signature = microzig.chip.types.peripherals.CPU.CPU_CCP;

fn hex(comptime v: u16) []const u8 {
    // std.fmt is deliberately avoided here; this is comptime only.
    const digits = "0123456789ABCDEF";
    comptime var out: []const u8 = "";
    if (v == 0) return "0";
    comptime {
        var v_ = v;
        while (v_ != 0) : (v_ >>= 4) {
            out = ([1]u8{digits[v_ & 0xF]} ++ out);
        }
    }
    return "0x" ++ out;
}

/// Write a CCP-protected I/O register in one indivisible assembly sequence.
///
/// DS40002413 section 7.4.6 "Configuration Change Protection (CCP)", page 37:
/// writing the IOREG signature to CPU.CCP opens a four-instruction window in
/// which protected I/O registers accept a write; interrupts are ignored for
/// the duration of the window.
///
/// Two separate volatile stores do NOT prove the window: the compiler may
/// interleave loads, spills or other stores between them, and reordering would
/// silently drop the write. One inline-assembly statement guarantees
/// adjacency: `ldi`, `out`, `sts` -- three instructions of the four allowed,
/// with the key load first so the protected store lands inside the window.
///
/// `address` must be comptime so it is baked into the `sts` immediate rather
/// than computed by instructions inside the window.
///
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=37
pub inline fn write_io(comptime address: u16, value: u8) void {
    // CPU.CCP data address 0x34 => I/O 0x14 (AVR data-space = I/O + 0x20).
    const ccp_io = comptime hex(@as(u16, @intCast(ccp_address - 0x20)));
    var sig: u8 = undefined;
    asm volatile ("ldi %[sig], " ++ hex(@backingInt(Signature.IOREG)) ++ "\n" ++
            "out " ++ ccp_io ++ ", %[sig]\n" ++
            "sts " ++ hex(address) ++ ", %[val]"
        : [sig] "=&d" (sig),
        : [val] "r" (value),
        : "memory",
    );
}

/// Write a CCP-protected register that requires the SPM key (`CPU.CCP = SPM`).
///
/// Used only by NVMCTRL.CTRLA. Same four-instruction window as `write_io`.
/// DS40002413 section 11.3.6 "Configuration Change Protection", page 79.
/// https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=79
pub inline fn write_spm(comptime address: u16, value: u8) void {
    const ccp_io = comptime hex(@as(u16, @intCast(ccp_address - 0x20)));
    var sig: u8 = undefined;
    asm volatile ("ldi %[sig], " ++ hex(@backingInt(Signature.SPM)) ++ "\n" ++
            "out " ++ ccp_io ++ ", %[sig]\n" ++
            "sts " ++ hex(address) ++ ", %[val]"
        : [sig] "=&d" (sig),
        : [val] "r" (value),
        : "memory",
    );
}

test "hex formatting" {
    try @import("std").testing.expectEqualStrings("0xD8", hex(0xD8));
    try @import("std").testing.expectEqualStrings("0x34", hex(0x34));
    try @import("std").testing.expectEqualStrings("0x1400", hex(0x1400));
}
