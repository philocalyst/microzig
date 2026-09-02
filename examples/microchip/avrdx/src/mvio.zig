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
    const dual_supply = hal.mvio.system_configuration() == .DUAL;

    // VDDIO2/10 against the 1.024V reference: a 3.3V rail reads as 330 mV,
    // comfortably inside range.
    hal.adc.configure(.{
        .channel = .vddio2_div10,
        .reference = .@"1V024",
        .resolution = .@"12BIT",
        .prescaler = .DIV16,
        .configure_pin = false,
    });

    var show_fault = false;

    while (true) {
        if (dual_supply) {
            // Park the MVIO output low whenever its supply is absent; a
            // floating or back-powered pad can leak into the peripheral.
            show_fault = !hal.mvio.vddio2_ok();
            if (show_fault) {
                mvio_out.put(false);
                status.put(show_fault);
                continue;
            }
        }

        // Drive the MVIO pin and mirror "supply present" on the LED.
        hal.gpio.configure_output(mvio_out, true);

        hal.adc.start();
        while (!hal.adc.result_ready()) {}
        const raw = hal.adc.average(hal.adc.read_raw(), .ACC16);
        const mvio_mv = hal.adc.to_millivolts(raw, .@"1V024", .@"12BIT") * 10;

        // LED on means healthy: the measured rail is within 10% of nominal.
        const nominal: u32 = if (dual_supply) 3300 else 5000;
        status.put(mvio_mv * 100 > nominal * 90);

        // Slow blink cadence so the fault state is visible.
        delay_ms(250);
    }
}

fn delay_ms(ms: u16) void {
    var remaining = ms;
    while (remaining > 0) : (remaining -= 1) {
        var cycles: u16 = 1000;
        while (cycles > 0) : (cycles -= 1) {
            asm volatile ("nop");
        }
    }
}

comptime {
    _ = microzig.export_startup();
}
