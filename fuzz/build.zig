const std = @import("std");

const pkg_name = "cron";
const pkg_path = "../src/lib.zig";

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "fuzz",
        .root_source_file = .{ .path = "./fuzz.zig" },
        .target = target,
        .optimize = optimize,
    });

    const datetime_module = b.addModule("datetime", .{
        .source_file = .{ .path = "../deps/zig-datetime/src/main.zig" },
    });
    const mod = b.addModule("cron", .{
        .source_file = .{ .path = "../src/lib.zig" },
        .dependencies = &.{.{ .name = "datetime", .module = datetime_module }},
    });
    exe.addModule("cron", mod);

    exe.addModule("datetime", datetime_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run-fuzz", "Run fuzz tests");
    run_step.dependOn(&run_cmd.step);
}
