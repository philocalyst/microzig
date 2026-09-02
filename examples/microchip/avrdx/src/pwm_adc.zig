//! Read a potentiometer on PD4 and use it to set the brightness of an LED on
//! PA0, driven by TCA0's first PWM channel.
//!
//! Shows the two places AVR Dx differs most from tinyAVR: the 12-bit ADC with
//! its own reference register, and TCA0's three compare channels.

const microzig = @import("microzig");
const hal = microzig.hal;

/// TCA0 WO0 in the PORTA position.
const led = hal.gpio.pins.pa0;
/// ADC0 AIN4.
const pot_channel: hal.adc.PositiveChannel = .ain4_pd4;

const pwm_top: u16 = 1023;

pub fn main() void {
    hal.clock.set_internal_frequency(.mhz24, .{});
    hal.clock.disable_prescaler();

    // WO0..WO5 land on PA0..PA5 in this position. The peripheral overrides the
    // pin value but not its direction, so PA0 still has to be an output.
    hal.portmux.set_tca0(.PORTA);
    hal.gpio.set_direction(led, .output);

    hal.tca0.single.configure(.{
        .waveform = .SINGLESLOPE,
        .clock = .DIV8,
        .period = pwm_top,
        .compare = .{ 0, 0, 0 },
        .enable_output = .{ true, false, false },
    });

    // Accumulate 16 samples per reading to average out noise from the PWM
    // switching on the same die.
    hal.adc.configure(.{
        .channel = pot_channel,
        .reference = .VDD,
        .resolution = .@"12BIT",
        .accumulation = .ACC16,
        .prescaler = .DIV16,
        .free_running = true,
    });
    hal.adc.start();

    while (true) {
        if (hal.adc.result_ready()) {
            // RES holds the sum of the burst, so divide back down before
            // scaling. 12-bit full scale is 4095, the PWM top is 1023.
            const reading = hal.adc.average(hal.adc.read_raw(), .ACC16);
            hal.tca0.single.set_compare(.cmp0, reading >> 2);
        }
    }
}

comptime {
    _ = microzig.export_startup();
}
