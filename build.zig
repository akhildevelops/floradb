const std = @import("std");
const builtin = @import("builtin");
pub fn build(b: *std.Build) void {
    if (builtin.os.tag != .linux) {
        @panic("Currently flora supports only Linux based systems.");
    }
    // Build Parameters
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const module = b.dependency("arrow_zig", .{ .target = target, .optimize = optimize }).module("arrow");
    // Library
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("arrow", module);

    // Executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("flora64", lib_mod);

    const exe = b.addExecutable(.{
        .name = "flora64",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test Suite
    const all_tests_module = b.createModule(.{
        .root_source_file = b.path("test/all.zig"),
        .target = target,
        .optimize = optimize,
    });
    all_tests_module.addImport("flora64", lib_mod);
    const all_tests = b.addTest(.{ .root_module = all_tests_module });
    const all_tests_run_step = b.addRunArtifact(all_tests);
    const intall_test = b.addInstallArtifact(all_tests, .{ .dest_sub_path = "test" });
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&all_tests_run_step.step);
    test_step.dependOn(&intall_test.step);
}
