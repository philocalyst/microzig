//! Echo over USART0 at 115200 baud on PA0 (TxD) and PA1 (RxD), print the
//! device identity on start-up, and report the die temperature whenever a
//! 't' arrives.

const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;

const clk_per_hz = 24_000_000;

const uart = hal.usart.Usart.usart0;

var writer_buffer: [64]u8 = undefined;

pub fn main() void {
    hal.clock.set_internal_frequency(.mhz24, .{});
    hal.clock.disable_prescaler();

    // Default position: TxD PA0, RxD PA1.
    hal.portmux.set_usart0(.default);
    hal.gpio.set_direction(hal.gpio.pins.pa0, .output);
    hal.gpio.set_direction(hal.gpio.pins.pa1, .input);

    uart.configure(.{
        .baud_rate = 115_200,
        .clk_per_hz = clk_per_hz,
    }) catch {
        // 115200 is comfortably reachable at 24 MHz; if the clock setup above
        // is ever changed to something that cannot express it, stop here
        // rather than transmitting garbage.
        while (true) {}
    };

    var w = uart.writer(&writer_buffer);
    const out = &w.interface;

    const id = hal.device.device_id();
    out.print("AVR32DD20 up. signature {X:0>2} {X:0>2} {X:0>2}, rev {c}\r\n", .{
        id[0], id[1], id[2], hal.device.revision_letter(),
    }) catch {};
    out.print("reset flags: {any}\r\n", .{hal.reset.take_flags()}) catch {};
    out.print("send 't' for die temperature\r\n", .{}) catch {};
    out.flush() catch {};

    // The temperature sensor needs its own ADC setup: the internal 2.048V
    // reference the factory calibration was taken against, a settling delay
    // and a long sample time, and no accumulation. `temperature_config`
    // derives the delay and sample length from the ADC clock.
    const adc_prescaler: hal.adc.Prescaler = .div16;
    const clk_adc_hz: u32 = clk_per_hz / @as(u32, adc_prescaler.divisor());
    hal.adc.configure(hal.adc.temperature_config(clk_adc_hz, adc_prescaler));

    while (true) {
        const byte = uart.read_byte();

        if (byte == 't') {
            const kelvin = hal.adc.read_temperature_kelvin();
            const celsius = @as(i16, @intCast(kelvin)) - 273;
            out.print("die: {d} K ({d} C)\r\n", .{ kelvin, celsius }) catch {};
            out.flush() catch {};
        } else {
            uart.write_byte(byte);
        }
    }
}
