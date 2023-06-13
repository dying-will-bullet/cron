const std = @import("std");

const pkg_name = "cron";
const pkg_path = "../src/lib.zig";

const examples = .{
    "scheduler",
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (examples) |e| {
        const example_path = e ++ "/main.zig";
        const exe_name = "example-" ++ e;
        const run_name = "run-" ++ e;
        const run_desc = "Run the " ++ e ++ " example";

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_source_file = .{ .path = example_path },
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
        const run_step = b.step(run_name, run_desc);
        run_step.dependOn(&run_cmd.step);
    }
}
