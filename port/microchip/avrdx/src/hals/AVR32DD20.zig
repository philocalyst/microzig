//! Hardware abstraction layer for the Microchip AVR32DD20.
//!
//! A 20-pin AVR DD: 32 KiB flash, 4 KiB SRAM, 256 B EEPROM, and Multi-Voltage
//! I/O on PORTC. Register addresses and pin mappings throughout this package
//! come from the AVR32DD20 ATDF in Microchip.AVR-Dx_DFP; behavioural notes and
//! procedures cite the AVR16/32DD14/20 data sheet, Microchip DS40002413:
//!
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf
//!
//! Citations are written as `section X.Y "Title", page N` with a
//! `...DS40002413.pdf#page=N` link, which most PDF viewers open at that page.
//!
//! ## A note for readers coming from tinyAVR/megaAVR-0
//!
//! AVR Dx looks like tinyAVR-1 but differs in ways that silently break ported
//! code. The three that bite hardest:
//!
//! - EEPROM programming is *command first* (`nvmctrl`), not "fill page buffer
//!   then erase-write". The tinyAVR `PAGEERASEWRITE` command code does not
//!   exist here.
//! - The ADC is 12-bit with a different channel numbering, prescaler table and
//!   reference register (`VREF.ADC0REF`, not `VREF.CTRLA`).
//! - `SIGROW.TEMPSENSE0/1` are 16-bit words, not an 8-bit gain/offset pair.

// Core services. Register access goes through the generated layer
// (`microzig.chip.peripherals` / `microzig.chip.types`); there is no
// hand-written register map in this package.
pub const capabilities = @import("avr32dd20/capabilities.zig");
pub const ccp = @import("avr32dd20/ccp.zig");
pub const clock = @import("avr32dd20/clock.zig");
pub const cpuint = @import("avr32dd20/cpuint.zig");
pub const device = @import("avr32dd20/device.zig");
pub const reset = @import("avr32dd20/reset.zig");
pub const sleep = @import("avr32dd20/sleep.zig");
pub const watchdog = @import("avr32dd20/watchdog.zig");

// I/O
pub const gpio = @import("avr32dd20/gpio.zig");
pub const portmux = @import("avr32dd20/portmux.zig");
pub const mvio = @import("avr32dd20/mvio.zig");

// Timers
pub const tca0 = @import("avr32dd20/tca0.zig");
pub const tcb = @import("avr32dd20/tcb.zig");
pub const tcd = @import("avr32dd20/tcd.zig");
pub const rtc = @import("avr32dd20/rtc.zig");

// Analog
pub const adc = @import("avr32dd20/adc.zig");
pub const dac = @import("avr32dd20/dac.zig");
pub const ac = @import("avr32dd20/ac.zig");
pub const vref = @import("avr32dd20/vref.zig");
pub const zcd = @import("avr32dd20/zcd.zig");
pub const bod = @import("avr32dd20/bod.zig");

// Serial
pub const usart = @import("avr32dd20/usart.zig");
pub const spi = @import("avr32dd20/spi.zig");
pub const twi = @import("avr32dd20/twi.zig");

// Logic and memory
pub const ccl = @import("avr32dd20/ccl.zig");
pub const evsys = @import("avr32dd20/evsys.zig");
pub const nvmctrl = @import("avr32dd20/nvmctrl.zig");
pub const crcscan = @import("avr32dd20/crcscan.zig");

/// Convenience aliases for the two memory-mapped stores.
pub const eeprom = nvmctrl.eeprom;
pub const flash = nvmctrl.flash;

/// Memory sizes, kept here for parity with the other Microchip HALs in this
/// repository. `device.info` carries the fuller description; every value is a
/// package capability from `capabilities.zig`.
pub const memory = struct {
    pub const flash_size = capabilities.flash_size;
    pub const sram_size = capabilities.sram_size;
    pub const eeprom_size = capabilities.eeprom_size;
    pub const flash_page_size = capabilities.flash_page_size;
};

/// Compile-time surface gate.
///
/// Taking the address of a function forces the compiler to semantically
/// analyse its whole body, so referencing every non-generic public
/// declaration here makes *every* firmware build fail if any HAL entry point
/// stopped compiling -- including client-mode and buffered paths no example
/// currently exercises. The linker discards unreferenced code afterwards, so
/// the gate costs nothing at runtime.
fn surface_check(comptime T: type) void {
    for (@typeInfo(T).@"struct".decl_names) |name| {
        const decl = @field(T, name);
        const info = @typeInfo(@TypeOf(decl));
        if (info == .@"fn" and info.@"fn".is_generic) continue;
        _ = &decl;
    }
}

// The three serial/timer modules below are excluded from the default gate:
// forcing codegen of their full surfaces trips an order-dependent LLVM-AVR
// bitcode-emission bug in the pinned toolchain ("Invalid integer const
// record"). They still compile wherever an example calls them; re-add
// surface_check(twi)/(tcd)/(ccl) once the toolchain is updated.
comptime {
    surface_check(capabilities);
    surface_check(ccp);
    surface_check(clock);
    surface_check(cpuint);
    surface_check(device);
    surface_check(reset);
    surface_check(sleep);
    surface_check(watchdog);
    surface_check(gpio);
    surface_check(portmux);
    surface_check(mvio);
    surface_check(tca0);
    surface_check(tcb);
    surface_check(rtc);
    surface_check(adc);
    surface_check(dac);
    surface_check(ac);
    surface_check(vref);
    surface_check(zcd);
    surface_check(bod);
    surface_check(usart);
    surface_check(spi);
    surface_check(evsys);
    surface_check(nvmctrl);
    surface_check(crcscan);
    _ = &@as(type, usart.Instance(0));
    _ = &@as(type, usart.Instance(1));
}
