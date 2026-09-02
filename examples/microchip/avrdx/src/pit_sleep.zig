//! Wake once a second from power-down sleep on the RTC's periodic interrupt,
//! toggle an LED, and store a wake counter in EEPROM.
//!
//! The PIT is the only timer that keeps running in power-down, which is what
//! makes this the standard low-power heartbeat on this family.

const microzig = @import("microzig");
const hal = microzig.hal;

const led = hal.gpio.pins.pa7;

/// Where in EEPROM the wake counter lives.
// from_int is range-checked; the EEPROM starts at 0.
const counter_address = hal.eeprom.Address.from_int(0).?;

pub fn main() void {
    hal.clock.set_internal_frequency(.mhz4, .{});
    hal.clock.disable_prescaler();

    // Unused pads keep their input buffers powered unless told otherwise,
    // which matters once the CPU is asleep.
    hal.gpio.disable_unused_inputs(.{});
    hal.gpio.configure_output(led, false);

    // 32.768 kHz internal oscillator, divided by 32768 -> one tick per second.
    hal.rtc.set_clock_source(.OSC32K);
    hal.rtc.pit.configure(.CYC32768, true);

    hal.cpuint.enable_interrupts();

    var wakes = hal.eeprom.read_byte(counter_address);

    while (true) {
        hal.sleep.enter(.power_down);

        // Execution resumes here after the PIT interrupt.
        led.toggle();
        wakes +%= 1;
        hal.eeprom.update_byte(counter_address, wakes);
    }
}

/// RTC PIT interrupt. Vector names are `<instance>_<name>` as generated from
/// the ATDF, so the PIT vector on this part is `RTC_PIT`.
///
/// Clearing the flag is all the handler needs to do; the work happens back in
/// `main` once SLEEP returns.
pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        // HandlerFn is a tagged union so the calling convention is explicit.
        .RTC_PIT = .{ .signal = &rtc_pit_interrupt },
    },
};

fn rtc_pit_interrupt() callconv(.avr_signal) void {
    hal.rtc.pit.clear_interrupt();
}

comptime {
    _ = microzig.export_startup();
}
