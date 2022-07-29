const std = @import("std");
const Builder = std.build.Builder;

const Program = struct {
    name: []const u8,
    path: []const u8,
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const examples = [_]Program{
        .{
            .name = "lines",
            .path = "examples/lines.zig",
        },
        .{
            .name = "balls",
            .path = "examples/balls.zig",
        },
        .{
            .name = "chart",
            .path = "examples/chart.zig",
        },
        .{
            .name = "image",
            .path = "examples/image.zig",
        },
        .{
            .name = "dither",
            .path = "examples/dither.zig",
        },
        .{
            .name = "logo",
            .path = "examples/logo.zig",
        },
    };

    const examples_step = b.step("examples", "Builds all the examples");

    for (examples) |ex| {
        const exe = b.addExecutable(ex.name, ex.path);

        exe.setBuildMode(mode);
        exe.setTarget(target);
        
        
        exe.addPackagePath("zig-drawille", "src/main.zig");
        exe.addPackagePath("zigimg", "lib/zigimg/zigimg.zig");

        const run_cmd = exe.run();
        const run_step = b.step(ex.name, ex.name);
        run_step.dependOn(&run_cmd.step);
        examples_step.dependOn(&exe.step);
    }
}
