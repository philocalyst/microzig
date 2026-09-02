//! PORTMUX - peripheral pin routing.
//!
//! DS40002413 section 17 "PORTMUX - Port Multiplexer", page 153.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=153
//!
//! Only the routings that land on a pad bonded out by the 20-pin package are
//! listed. The pin lists in each doc comment come from the AVR32DD20 ATDF's
//! PORTMUX value groups (the same encodings the generated register layer
//! carries), so they describe this package specifically -- several options
//! reach more pins on DD28/DD32.
//!
//! TCB note: the ATDF gives TCB0/TCB1 only their DEFAULT routes (WO on PA2 and
//! PA3); the TCBROUTEA bits carry no alternative encodings. A TCB waveform
//! output is therefore enabled with TCBn.CTRLB.CCMPEN, not here -- see `tcb`.

const microzig = @import("microzig");

const portmux = microzig.chip.peripherals.PORTMUX;

/// PORTMUX.USARTROUTEA.USART0.
pub const Usart0 = @TypeOf(portmux.USARTROUTEA.read().USART0);

/// PORTMUX.USARTROUTEA.USART1.
pub const Usart1 = @TypeOf(portmux.USARTROUTEA.read().USART1);

/// PORTMUX.SPIROUTEA.SPI0.
pub const Spi0 = @TypeOf(portmux.SPIROUTEA.read().SPI0);

/// PORTMUX.TWIROUTEA.TWI0.
pub const Twi0 = @TypeOf(portmux.TWIROUTEA.read().TWI0);

/// PORTMUX.TCAROUTEA.TCA0.
pub const Tca0 = @TypeOf(portmux.TCAROUTEA.read().TCA0);

/// PORTMUX.TCDROUTEA.TCD0.
pub const Tcd0 = @TypeOf(portmux.TCDROUTEA.read().TCD0);

/// PORTMUX.EVSYSROUTEA.EVOUTA.
pub const EventOutputA = @TypeOf(portmux.EVSYSROUTEA.read().EVOUTA);

/// PORTMUX.EVSYSROUTEA.EVOUTC.
pub const EventOutputC = @TypeOf(portmux.EVSYSROUTEA.read().EVOUTC);

/// PORTMUX.EVSYSROUTEA.EVOUTD.
pub const EventOutputD = @TypeOf(portmux.EVSYSROUTEA.read().EVOUTD);

/// PORTMUX.CCLROUTEA.LUT0.
pub const CclLut0 = @TypeOf(portmux.CCLROUTEA.read().LUT0);

/// PORTMUX.CCLROUTEA.LUT1.
pub const CclLut1 = @TypeOf(portmux.CCLROUTEA.read().LUT1);

/// PORTMUX.CCLROUTEA.LUT2.
pub const CclLut2 = @TypeOf(portmux.CCLROUTEA.read().LUT2);

// Route documentation, transcribed from the ATDF value-group captions for the
// 20-pin MVIO package. The enums themselves are re-exported from the generated
// layer above; these aliases exist so callers can read the pin mapping at the
// call site without opening the datasheet.
//
// Usart0:
//   .DEFAULT -- TxD PA0, RxD PA1, XCK PA2, XDIR PA3.
//   .ALT1    -- TxD PA4, RxD PA5, XCK PA6, XDIR PA7.
//   .ALT2    -- TxD PA2, RxD PA3. No XCK or XDIR.
//   .ALT3    -- TxD PD4, RxD PD5, XCK PD6, XDIR PD7.
//   .ALT4    -- TxD PC1, RxD PC2, XCK PC3. No XDIR. These are MVIO pins.
//   .NONE    -- not connected to any pin.
//
// Usart1:
//   .DEFAULT -- RxD PC1, XCK PC2, XDIR PC3. No TxD pad on this package:
//               receive-only.
//   .ALT2    -- TxD PD6, RxD PD7.
//   .NONE    -- not connected.
//
// Spi0:
//   .DEFAULT -- MOSI PA4, MISO PA5, SCK PA6, SS PA7.
//   .ALT3    -- MOSI PA0, MISO PA1, SS PC1. No SCK pad: client-mode position.
//   .ALT4    -- MOSI PD4, MISO PD5, SCK PD6, SS PD7.
//   .ALT5    -- MISO PC1, SCK PC2, SS PC3. No MOSI pad.
//   .ALT6    -- MOSI PC1, MISO PC2, SCK PC3, SS PF7.
//   .NONE    -- not connected; SS driven to 1 internally.
//
// Twi0:
//   .DEFAULT -- SDA PA2, SCL PA3. Dual-mode client: SDA PC2, SCL PC3.
//   .ALT1    -- SDA PA2, SCL PA3. Dual mode disabled.
//   .ALT2    -- SDA PC2, SCL PC3. Dual mode disabled.
//   .ALT3    -- SDA PA0, SCL PA1. Dual-mode client: SDA PC2, SCL PC3.
//
// Tca0:
//   .PORTA -- WO0..WO5 on PA0..PA5.
//   .PORTC -- WO1..WO3 on PC1..PC3; WO0/WO4/WO5 have no pad here.
//   .PORTD -- WO4 on PD4 and WO5 on PD5 only.
//
// Tcd0:
//   .DEFAULT -- WOA PA4, WOB PA5, WOC PA6, WOD PA7.
//   .ALT4    -- WOA PA4, WOB PA5, WOC PD4, WOD PD5.

/// Route USART0 pins; peripheral stays functional across changes.
pub fn set_usart0(route: Usart0) void {
    portmux.USARTROUTEA.modify(.{ .USART0 = route });
}

/// Route USART1 pins.
pub fn set_usart1(route: Usart1) void {
    portmux.USARTROUTEA.modify(.{ .USART1 = route });
}

/// Route SPI0 pins.
pub fn set_spi0(route: Spi0) void {
    portmux.SPIROUTEA.modify(.{ .SPI0 = route });
}

/// Route TWI0 host and client pins.
pub fn set_twi0(route: Twi0) void {
    portmux.TWIROUTEA.modify(.{ .TWI0 = route });
}

/// Route the TCA0 waveform output(s).
pub fn set_tca0(route: Tca0) void {
    portmux.TCAROUTEA.modify(.{ .TCA0 = route });
}

/// Route the TCD0 waveform output base port.
pub fn set_tcd0(route: Tcd0) void {
    portmux.TCDROUTEA.modify(.{ .TCD0 = route });
}

/// Route event user EVOUTA onto a pin.
pub fn set_event_output_a(route: EventOutputA) void {
    portmux.EVSYSROUTEA.modify(.{ .EVOUTA = route });
}

/// Route event user EVOUTC onto a pin (PC2 on this package; ATDF DEFAULT only).
pub fn set_event_output_c(route: EventOutputC) void {
    portmux.EVSYSROUTEA.modify(.{ .EVOUTC = route });
}

/// Route event user EVOUTD onto a pin.
pub fn set_event_output_d(route: EventOutputD) void {
    portmux.EVSYSROUTEA.modify(.{ .EVOUTD = route });
}

/// Route LUT0 output onto a pin.
pub fn set_ccl_lut0(route: CclLut0) void {
    portmux.CCLROUTEA.modify(.{ .LUT0 = route });
}

/// Route LUT1 output onto a pin.
pub fn set_ccl_lut1(route: CclLut1) void {
    portmux.CCLROUTEA.modify(.{ .LUT1 = route });
}

/// Route LUT2 output onto a pin.
pub fn set_ccl_lut2(route: CclLut2) void {
    portmux.CCLROUTEA.modify(.{ .LUT2 = route });
}
