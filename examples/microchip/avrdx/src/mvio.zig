//! Multi-Voltage I/O: drive PORTC only while its separate VDDIO2 supply is
//! present, and measure that supply with the ADC.
//!
//! MVIO is the feature that distinguishes AVR DD from the rest of the AVR Dx
//! line. On the 20-pin package PC1..PC3 are powered from the VDDIO2 pin, so
//! they can talk to a 1.8V peripheral while the core runs at 5V.

const microzig = @import("microzig");
const hal = microzig.hal;

/// An MVIO pin, powered from VDDIO2.
const mvio_out = hal.gpio.pins.pc1;
/// Status LED on the normal VDD domain.
const status = hal.gpio.pins.pa7;

pub fn main() void {
    hal.clock.set_internal_frequency(.mhz4, .{});
    hal.clock.disable_prescaler();

    hal.gpio.configure_output(status, false);

    // In single-supply mode VDDIO2 is tied to VDD and `vddio2_ok` is always
    // true, so this same code works on a board wired either way.
    const dual_supply = hal.mvio.system_configuration() == .dual_supply;

    // VDDIO2/10 against the 1.024V reference: a 3.3V rail reads as 330 mV,
    // comfortably inside range.
    hal.adc.configure(.{
        .channel = .vddio2_div10,
        .reference = .internal_1v024,
        .resolution = .bits12,
        .prescaler = .div16,
        .configure_pin = false,
    });

    // Nothing on PORTC is meaningful until the second supply is up.
    hal.mvio.wait_for_vddio2();
    hal.gpio.configure_output(mvio_out, false);

    while (true) {
        if (!hal.mvio.vddio2_ok()) {
            // Park the MVIO pin and wait for the supply to come back rather
            // than driving a pad with no supply behind it.
            hal.gpio.set_direction(mvio_out, .input);
            status.put(false);
            hal.mvio.wait_for_vddio2();
            hal.gpio.configure_output(mvio_out, false);
        }

        const raw = hal.adc.read_blocking();
        const rail_mv = hal.adc.to_millivolts(raw, .internal_1v024, .bits12) *
            hal.mvio.measurement_divisor;

        // Light the status LED once VDDIO2 is above 3V.
        status.put(rail_mv > 3000);
        mvio_out.toggle();

        if (!dual_supply) {
            // Single-supply board: one pass is enough to show the reading.
            status.put(true);
        }

        var delay: u16 = 0;
        while (delay < 20_000) : (delay += 1) asm volatile ("nop");
    }
}
