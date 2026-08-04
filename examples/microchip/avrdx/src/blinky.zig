//! Blink an LED on PA7 of an AVR32DD20.
//!
//! PA7 is the CLKOUT/EVOUTA pin and the SPI0 SS pin in the default position,
//! so it is free here and convenient on a bare part.

const microzig = @import("microzig");
const hal = microzig.hal;

const led = hal.gpio.pins.pa7;

pub fn main() void {
    // Run at 4 MHz, the reset default, with the prescaler off. Explicit
    // because the delay loop below is calibrated against it.
    hal.clock.set_internal_frequency(.mhz4, .{});
    hal.clock.disable_prescaler();

    hal.gpio.configure_output(led, false);

    while (true) {
        led.toggle();
        delay_ms(500);
    }
}

/// Rough busy-wait. `microzig.cpu` has no AVR delay helper, and a timer would
/// obscure the point of the example.
fn delay_ms(milliseconds: u16) void {
    var remaining = milliseconds;
    while (remaining > 0) : (remaining -= 1) {
        // 4 MHz / 1000 = 4000 cycles per millisecond; the loop body is roughly
        // four cycles.
        var cycles: u16 = 1000;
        while (cycles > 0) : (cycles -= 1) {
            asm volatile ("nop");
        }
    }
}
