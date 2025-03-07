const std = @import("std");
const Pkg = std.build.Pkg;

const examples = .{
    "scheduler",
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "cron",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const opts = .{ .target = target, .optimize = optimize };
    const datetime_module = b.dependency("datetime", opts).module("datetime");
    lib.root_module.addImport("datetime", datetime_module);
    // lib.addModule("datetime", datetime_module);

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Docs
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&docs_install.step);
    b.default_step.dependOn(docs_step);

    const mod = b.addModule("cron", .{
        .root_source_file = b.path("src/lib.zig"),
        .imports = &.{.{ .name = "datetime", .module = datetime_module }},
    });

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_tests.root_module.addImport("datetime", datetime_module);

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Build examples
    inline for (examples) |e| {
        const example_path = "examples/" ++ e ++ "/main.zig";
        const exe_name = "example-" ++ e;
        const run_name = "run-example-" ++ e;
        const run_desc = "Run the " ++ e ++ " example";

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_source_file = b.path(example_path),
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("cron", mod);
        exe.root_module.addImport("datetime", datetime_module);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());
        const run_step = b.step(run_name, run_desc);
        run_step.dependOn(&run_cmd.step);
    }

    // Build fuzz
    const fuzz_exe = b.addExecutable(.{
        .name = "fuzz",
        .root_source_file = b.path("./fuzz/fuzz.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzz_exe.root_module.addImport("cron", mod);
    fuzz_exe.root_module.addImport("datetime", datetime_module);

    b.installArtifact(fuzz_exe);

    const run_fuzz_cmd = b.addRunArtifact(fuzz_exe);
    run_fuzz_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run-fuzz", "Run fuzz tests");
    run_step.dependOn(&run_fuzz_cmd.step);
}
