//! Echo over USART0 at 115200 baud on PA0 (TxD) and PA1 (RxD), print the
//! device identity on start-up, and report the die temperature whenever a
//! 't' arrives.
//!
//! Printing is done with tiny local formatters over `write_byte` instead of
//! `std.Io.Writer.print`: the generic print machinery still trips a codegen
//! bug in current Zig master for AVR ("Invalid integer const record"), and a
//! fixed-width hex/decimal writer is all this example needs anyway.

const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;

const clk_per_hz = 24_000_000;

const uart = hal.usart.Usart.usart0;

fn write_str(bytes: []const u8) void {
    for (bytes) |b| uart.write_byte(b);
}

fn write_hex_byte(v: u8) void {
    const digits = "0123456789ABCDEF";
    uart.write_byte(digits[v >> 4]);
    uart.write_byte(digits[v & 0x0F]);
}

fn write_u16(value: u16) void {
    var buf: [5]u8 = undefined;
    var n: usize = 0;
    var v = value;
    if (v == 0) {
        uart.write_byte('0');
        return;
    }
    while (v != 0) : (v /= 10) {
        buf[n] = '0' + @as(u8, @intCast(v % 10));
        n += 1;
    }
    while (n > 0) {
        n -= 1;
        uart.write_byte(buf[n]);
    }
}

fn write_i16(value: i16) void {
    if (value < 0) {
        uart.write_byte('-');
        write_u16(@intCast(-@as(i32, value)));
    } else {
        write_u16(@intCast(value));
    }
}

pub fn main() void {
    hal.clock.set_internal_frequency(.mhz24, .{});
    hal.clock.disable_prescaler();

    // Default position: TxD PA0, RxD PA1.
    hal.portmux.set_usart0(.DEFAULT);
    hal.gpio.configure_output(hal.gpio.pins.pa0, true);
    hal.gpio.configure_input(hal.gpio.pins.pa1, .{});

    uart.configure(.{
        .baud_rate = 115_200,
        .clk_per_hz = clk_per_hz,
    }) catch {
        // 115200 is comfortably reachable at 24 MHz; if the clock setup above
        // is ever changed to something that cannot express it, stop here
        // rather than transmitting garbage.
        while (true) {}
    };

    const id = hal.device.device_id();
    write_str("AVR32DD20 up. signature ");
    write_hex_byte(id[0]);
    uart.write_byte(' ');
    write_hex_byte(id[1]);
    uart.write_byte(' ');
    write_hex_byte(id[2]);
    write_str(", rev ");
    uart.write_byte(hal.device.revision_letter());
    write_str("\r\nsend 't' for die temperature\r\n");
    uart.flush();

    // The temperature sensor needs its own ADC setup: the internal 2.048V
    // reference the factory calibration was taken against, a settling delay
    // and a long sample time, and no accumulation. `temperature_config`
    // derives the delay and sample length from the ADC clock.
    const adc_prescaler: hal.adc.Prescaler = .DIV16;
    const clk_adc_hz: u32 = clk_per_hz / @as(u32, hal.adc.prescaler_divisor(adc_prescaler));
    hal.adc.configure(hal.adc.temperature_config(clk_adc_hz, adc_prescaler));

    while (true) {
        const byte = uart.read_byte();

        if (byte == 't') {
            const kelvin = hal.adc.read_temperature_kelvin();
            const celsius = @as(i16, @intCast(kelvin)) - 273;
            write_str("die: ");
            write_u16(kelvin);
            write_str(" K (");
            write_i16(celsius);
            write_str(" C)\r\n");
            uart.flush();
        } else {
            uart.write_byte(byte);
        }
    }
}

comptime {
    _ = microzig.export_startup();
}
