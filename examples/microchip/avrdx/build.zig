const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .avrdx = true,
});

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const maybe_example = b.option([]const u8, "example", "only build matching examples");

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const available_examples = [_]Example{
        .{ .target = mb.ports.avrdx.chips.avr32dd20, .name = "avr32dd20_blinky", .file = "src/blinky.zig" },
        .{ .target = mb.ports.avrdx.chips.avr32dd20, .name = "avr32dd20_pwm_adc", .file = "src/pwm_adc.zig" },
        .{ .target = mb.ports.avrdx.chips.avr32dd20, .name = "avr32dd20_usart", .file = "src/usart.zig" },
        .{ .target = mb.ports.avrdx.chips.avr32dd20, .name = "avr32dd20_pit_sleep", .file = "src/pit_sleep.zig" },
        .{ .target = mb.ports.avrdx.chips.avr32dd20, .name = "avr32dd20_mvio", .file = "src/mvio.zig" },
        .{ .target = mb.ports.avrdx.chips.avr32dd20, .name = "avr32dd20_abi_probe", .file = "src/abi_probe.zig" },
    };

    for (available_examples) |example| {
        if (maybe_example) |selected_example|
            if (!std.mem.containsAtLeast(u8, example.name, 1, selected_example))
                continue;

        const fw = mb.add_firmware(.{
            .name = example.name,
            .target = example.target,
            .optimize = optimize,
            .root_source_file = b.path(example.file),
        });

        mb.install_firmware(fw, .{});
        mb.install_firmware(fw, .{ .format = .elf });
    }
}

const Example = struct {
    target: *const microzig.Target,
    name: []const u8,
    file: []const u8,
};
