//! EVSYS - Event System.
//!
//! DS40002413 section 16 "EVSYS - Event System", page 141.
//! https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf#page=141
//!
//! Six routing channels connect a generator to one or more users with no CPU
//! in the loop. Wiring is two steps: point a channel at a generator with
//! `set_channel`, then subscribe a user to that channel with `connect`.
//!
//! Which *pin* a channel can watch depends on the channel: channels 0 and 1
//! see PORTA, channels 2 and 3 see PORTC and PORTD, and channels 4 and 5 see
//! PORTF. Everything else is encoded identically on all six. `pin_generator`
//! enforces that mapping at run time rather than letting a silently-ignored
//! encoding through.

const regs = @import("registers.zig");
const gpio = @import("gpio.zig");

pub const Channel = enum(u3) {
    ch0 = 0,
    ch1 = 1,
    ch2 = 2,
    ch3 = 3,
    ch4 = 4,
    ch5 = 5,

    fn address(c: Channel) u16 {
        return regs.evsys.channel0 + @as(u16, @intFromEnum(c));
    }

    /// Ports whose pins this channel can use as a generator.
    pub fn visible_ports(c: Channel) []const gpio.Port {
        return switch (c) {
            .ch0, .ch1 => &.{.a},
            .ch2, .ch3 => &.{ .c, .d },
            .ch4, .ch5 => &.{.f},
        };
    }
};

/// Event generators available on every channel.
///
/// Values transcribed from the AVR32DD20 ATDF `EVSYS_CHANNELn` value groups.
/// Pin generators are excluded because their encoding is channel-dependent --
/// use `pin_generator` for those.
pub const Generator = enum(u8) {
    off = 0x00,
    updi_synch = 0x01,
    /// MVIO VDDIO2 status change.
    mvio = 0x05,
    rtc_overflow = 0x06,
    rtc_compare = 0x07,
    /// The PIT, pre-divided. These are the low-power periodic sources.
    rtc_pit_div8192 = 0x08,
    rtc_pit_div4096 = 0x09,
    rtc_pit_div2048 = 0x0A,
    rtc_pit_div1024 = 0x0B,
    ccl_lut0 = 0x10,
    ccl_lut1 = 0x11,
    ccl_lut2 = 0x12,
    ccl_lut3 = 0x13,
    ac0_out = 0x20,
    adc0_result_ready = 0x24,
    zcd3 = 0x30,
    usart0_xck = 0x60,
    usart1_xck = 0x61,
    spi0_sck = 0x68,
    /// TCA0 overflow in single mode, low underflow in split mode.
    tca0_overflow = 0x80,
    /// TCA0 high underflow, split mode only.
    tca0_high_underflow = 0x81,
    tca0_compare0 = 0x84,
    tca0_compare1 = 0x85,
    tca0_compare2 = 0x86,
    tcb0_capture = 0xA0,
    tcb0_overflow = 0xA1,
    tcb1_capture = 0xA2,
    tcb1_overflow = 0xA3,
    tcd0_compare_b_clear = 0xB0,
    _,
};

pub const PinGeneratorError = error{
    /// This channel cannot see that pin's port.
    PortNotVisibleFromChannel,
};

/// Encoding for using `pin` as `channel`'s generator.
///
/// The base is 0x40 plus the pin index, except that channels 2/3 place PORTD
/// at 0x4C and channels 4/5 place PORTF at 0x48 -- so this is a lookup, not
/// arithmetic on the port number.
pub fn pin_generator(channel: Channel, pin: gpio.Pin) PinGeneratorError!u8 {
    return switch (channel) {
        .ch0, .ch1 => switch (pin.port) {
            .a => 0x40 + @as(u8, pin.index),
            else => error.PortNotVisibleFromChannel,
        },
        .ch2, .ch3 => switch (pin.port) {
            .c => 0x40 + @as(u8, pin.index),
            .d => 0x48 + @as(u8, pin.index),
            else => error.PortNotVisibleFromChannel,
        },
        .ch4, .ch5 => switch (pin.port) {
            .f => 0x48 + @as(u8, pin.index),
            else => error.PortNotVisibleFromChannel,
        },
    };
}

/// An event user: a peripheral input a channel can drive.
pub const User = enum(u16) {
    ccl_lut0_a = regs.evsys.user.ccl_lut0_a,
    ccl_lut0_b = regs.evsys.user.ccl_lut0_b,
    ccl_lut1_a = regs.evsys.user.ccl_lut1_a,
    ccl_lut1_b = regs.evsys.user.ccl_lut1_b,
    ccl_lut2_a = regs.evsys.user.ccl_lut2_a,
    ccl_lut2_b = regs.evsys.user.ccl_lut2_b,
    ccl_lut3_a = regs.evsys.user.ccl_lut3_a,
    ccl_lut3_b = regs.evsys.user.ccl_lut3_b,
    adc0_start = regs.evsys.user.adc0_start,
    /// Event output on PA2, or PA7 via `portmux.set_event_output_a`.
    event_out_a = regs.evsys.user.evouta,
    /// Event output on PC2.
    event_out_c = regs.evsys.user.evoutc,
    /// Event output on PD7 via `portmux.set_event_output_d`.
    event_out_d = regs.evsys.user.evoutd,
    /// Event output on PF7, which is also the UPDI pin.
    event_out_f = regs.evsys.user.evoutf,
    usart0_irda = regs.evsys.user.usart0_irda,
    usart1_irda = regs.evsys.user.usart1_irda,
    tca0_count_a = regs.evsys.user.tca0_cnt_a,
    tca0_count_b = regs.evsys.user.tca0_cnt_b,
    tcb0_capture = regs.evsys.user.tcb0_capt,
    tcb0_count = regs.evsys.user.tcb0_count,
    tcb1_capture = regs.evsys.user.tcb1_capt,
    tcb1_count = regs.evsys.user.tcb1_count,
    tcd0_input_a = regs.evsys.user.tcd0_input_a,
    tcd0_input_b = regs.evsys.user.tcd0_input_b,
};

/// Point a channel at a generator.
pub fn set_channel(channel: Channel, generator: Generator) void {
    regs.write(channel.address(), @intFromEnum(generator));
}

/// Point a channel at a pin.
pub fn set_channel_pin(channel: Channel, pin: gpio.Pin) PinGeneratorError!void {
    regs.write(channel.address(), try pin_generator(channel, pin));
}

/// Point a channel at a generator encoding this module does not name. The
/// per-channel tables are in DS40002413 section 16.5.2 "Channel n Generator
/// Selection", page 146.
pub fn set_channel_raw(channel: Channel, generator: u8) void {
    regs.write(channel.address(), generator);
}

/// Subscribe a user to a channel.
///
/// User registers number channels from one, with zero meaning "not connected",
/// hence the +1.
pub fn connect(user: User, channel: Channel) void {
    regs.write(@intFromEnum(user), @as(u8, @intFromEnum(channel)) + 1);
}

pub fn disconnect(user: User) void {
    regs.write(@intFromEnum(user), 0);
}

/// Fire software event A on the channels named in `channel_mask`.
pub fn trigger_software_a(channel_mask: u8) void {
    regs.write(regs.evsys.sweventa, channel_mask);
}

pub fn trigger_software_b(channel_mask: u8) void {
    regs.write(regs.evsys.sweventb, channel_mask);
}
