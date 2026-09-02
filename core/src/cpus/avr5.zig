const avr = @import("avr_common.zig");
const avr_rt = @import("avr_rt.zig");

export const abort = avr.abort;

pub const interrupt = avr.interrupt;
pub const HandlerFn = avr.HandlerFn;
pub const Interrupt = avr.Interrupt;
pub const InterruptOptions = avr.InterruptOptions;

pub const sbi = avr.sbi;
pub const cbi = avr.cbi;

fn vector_table() linksection("microzig_flash_start") callconv(.naked) noreturn {
    asm volatile (avr.generate_vector_table_asm(.jmp));
}

pub fn export_startup_logic() void {
    _ = startup_logic;
    // The integer runtime routines are `export`ed from here so that they are
    // always emitted: LLVM lowers 32-bit multiply and 16/32-bit division on
    // AVR to calls into them, and compiler_rt is not bundled for AVR.
    _ = &avr_rt.__mulsi3;
    _ = &avr_rt.__udivmodsi4;
    _ = &avr_rt.__udivmodhi4;
    @export(&vector_table, .{
        .name = "_start",
    });
}

pub const startup_logic = avr.startup_logic;
