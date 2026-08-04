const std = @import("std");
const microzig = @import("microzig/build-internals");

const Self = @This();

chips: struct {
    avr32dd20: *const microzig.Target,
},

boards: struct {},

pub fn init(dep: *std.Build.Dependency) ?Self {
    const b = dep.builder;

    const atpack = b.lazyDependency("atpack", .{}) orelse return null;

    // AVR Dx parts map the low 32 KiB of flash into the data space and have no
    // RAMPZ, which is exactly what LLVM's avrxmega3 subtarget describes. The
    // device pack agrees: its objects for this part ship under gcc/dev/avr32dd20/avrxmega3/.
    const avrxmega3_target: std.Target.Query = .{
        .cpu_arch = .avr,
        .cpu_model = .{ .explicit = &std.Target.avr.cpu.avrxmega3 },
        .os_tag = .freestanding,
        .abi = .eabi,
    };

    // Memory layout taken from the AVR32DD20 ATDF address spaces:
    //   prog  PROGMEM        0x0000, 0x8000 bytes, 0x200 byte pages
    //   data  INTERNAL_SRAM  0x7000, 0x1000 bytes
    // Data-space regions are expressed with the 0x800000 offset that the AVR
    // linker uses to separate the data address space from program memory.
    const chip_avr32dd20: microzig.Target = .{
        .dep = dep,
        .preferred_binary_format = .hex,
        .zig_target = avrxmega3_target,
        .chip = .{
            .name = "AVR32DD20",
            .url = "https://www.microchip.com/en-us/product/AVR32DD20",
            .register_definition = .{
                .atdf = atpack.path("atdf/AVR32DD20.atdf"),
            },
            .memory_regions = &.{
                .{ .tag = .flash, .offset = 0x000000, .length = 32 * 1024, .access = .rx },
                .{ .tag = .ram, .offset = 0x807000, .length = 4 * 1024, .access = .rw },
            },
        },
        .hal = .{
            .root_source_file = b.path("src/hals/AVR32DD20.zig"),
        },
        .bundle_compiler_rt = false,
    };

    return .{
        .chips = .{
            .avr32dd20 = chip_avr32dd20.derive(.{}),
        },
        .boards = .{},
    };
}

pub fn build(b: *std.Build) void {
    _ = b.step("test", "Run platform agnostic unit tests");
}
