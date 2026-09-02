//! Chip capability metadata for the AVR32DD20 (20-pin MVIO package).
//!
//! These are facts the register schema cannot express: what the package
//! physically bonds, which pins can drive, which supply domain a port sits on,
//! which ADC channels are legal, and the memory geometry. Every entry traces
//! to either the ATDF pinout/address spaces or a DS40002413B table; the
//! source is named next to each fact.
//!
//! Package facts come from Microchip's AVR DD peripheral overview
//! (DS40002413B section 1) and the I/O multiplexing tables (section 7.3.1):
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=12

const std = @import("std");

/// Part this package implements.
pub const name = "AVR32DD20";

/// Device signature from the signature row (ATDF SIGNATURES property group).
/// Refuse to flash/run on anything else.
pub const expected_device_id: [3]u8 = .{ 0x1E, 0x95, 0x3A };

// -- Memory geometry (ATDF address spaces) -----------------------------------

/// Total flash, including the boot/application sections NVMCTRL knows about.
pub const flash_size: u32 = 32 * 1024;
/// Flash erase/write page size.
pub const flash_page_size: u16 = 512;
/// SRAM start in the data space.
pub const sram_base: u16 = 0x7000;
/// SRAM bytes in the data space starting at `sram_base`.
pub const sram_size: u16 = 4 * 1024;
/// Emulated EEPROM bytes managed by NVMCTRL.
pub const eeprom_size: u16 = 256;
/// EEPROM erases/writes one byte at a time on AVR Dx (NVMCTRL byte command),
/// unlike tinyAVR's page-oriented EEPROM.
pub const eeprom_page_size: u16 = 1;
/// Non-volatile user signature row bytes.
pub const user_row_size: u16 = 32;

/// Maximum rated CLK_MAIN/CPU frequency.
///
/// The ATDF variant carries speedmax="32000000", but that describes the
/// external-clock rating of the family; the electrical-limits chapter and the
/// family overview rate CLK_MAIN/CPU at 24 MHz for the DD series, reached
/// internally from OSCHF at 4.5-5.5V. The PDF wins over the ATDF attribute.
///
/// DS40002413B section 6.1 "Electrical Characteristics - Speed", table 6-1,
/// and section 12.3.4.1.1 "Internal High-Frequency Oscillator (OSCHF)".
/// The 32-48 MHz PLL output feeds TCD0 only -- it is never selectable as
/// CLK_MAIN (section 12.3.5).
pub const max_frequency_hz: u32 = 24_000_000;

/// Lowest rated supply voltage (millivolts) over temperature.
pub const vcc_min_mv: u16 = 1800;
/// Highest rated supply voltage (millivolts).
pub const vcc_max_mv: u16 = 5500;

// -- Package / pinout --------------------------------------------------------

/// Ports with at least one bonded pin on the 20-pin package.
pub const Port = enum(u2) {
    a,
    c,
    d,
    f,

    /// Mask of pins actually bonded out on the 20-pin package, from the ATDF
    /// DIP20MVIO/QFP20MVIO pinouts.
    pub fn available_pins(port: Port) u8 {
        return switch (port) {
            .a => 0b1111_1111, // PA0..PA7
            .c => 0b0000_1110, // PC1..PC3
            .d => 0b1111_0000, // PD4..PD7
            .f => 0b1100_0000, // PF6, PF7
        };
    }

    /// True when the package bonds this pin.
    pub fn bonded(port: Port, index: u3) bool {
        return (port.available_pins() & (@as(u8, 1) << index)) != 0;
    }

    /// True when the pin can drive a load.
    ///
    /// 17 of the bonded pins are bidirectional; PF6 is input-only because it
    /// doubles as RESET (or UPDI-capable GPIO depending on RSTPINCFG) and the
    /// datasheet's pinout marks it without an output driver claim. The family
    /// overview states 16 output-capable pins out of 17 bonded inputs.
    pub fn output_capable(port: Port, index: u3) bool {
        if (!port.bonded(index)) return false;
        return !(port == .f and index == 6);
    }

    pub const count_bonded: usize = blk: {
        var total: usize = 0;
        for (std.enums.values(Port)) |p| total += @popCount(p.available_pins());
        break :blk total;
    };

    pub const count_output_capable: usize = blk: {
        var total: usize = 0;
        for (std.enums.values(Port)) |p| {
            total += @popCount(p.available_pins());
            // PF6 is bonded but input-only.
            if (p == .f and p.bonded(6)) total -= 1;
        }
        break :blk total;
    };
};

/// Which supply domain powers a port. PORTC is the MVIO port on this package:
/// PC1..PC3 are powered from VDDIO2 (DS40002413B section 19 "MVIO").
pub const SupplyDomain = enum { vdd, vddio2 };

/// Which supply rail clocks a port's pads; PC1..PC3 sit on VDDIO2.
pub fn supply_domain(port: Port) SupplyDomain {
    return switch (port) {
        .c => .vddio2,
        else => .vdd,
    };
}

// -- MVIO-dependent analog availability --------------------------------------

/// True when the board is fused for dual-supply MVIO
/// (FUSE.SYSCFG1.MVSYSCFG = DUAL). Board code that ships single-supply should
/// override this to `false`.
///
/// DS40002413 peripheral-overview note 2: ADC (and AC) inputs on PORTC are
/// available only when MVIO is *disabled* (SINGLE). Drivers gate AIN29..AIN31 /
/// AC PC pads on `!mvio_enabled_by_fuse`.
/// https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-US-8/GUID-F94E51A5-03D0-474D-820B-5DF1CA77A1BD.html
pub const mvio_enabled_by_fuse: bool = true;

// -- Vector table geometry ----------------------------------------------------

/// Total vector slots including RESET and the reserved index 30.
pub const vector_count = 36;
/// The one reserved slot in the middle of the table (index 30).
pub const reserved_vectors = &[_]u16{30};

test "ATDF-backed geometry" {
    const testing = @import("std").testing;
    // AVR32DD20.atdf address spaces + DS40002413 Tables 8-1 / 8-3.
    try testing.expectEqual(@as(u32, 32 * 1024), flash_size);
    try testing.expectEqual(@as(u16, 512), flash_page_size);
    try testing.expectEqual(@as(u16, 4 * 1024), sram_size);
    try testing.expectEqual(@as(u16, 0x7000), sram_base);
    try testing.expectEqual(@as(u16, 256), eeprom_size);
    try testing.expectEqual(@as(u16, 1), eeprom_page_size);
    try testing.expectEqual(@as(u16, 32), user_row_size);
    try testing.expectEqual(@as(u32, 24_000_000), max_frequency_hz);
}

