const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("zterm", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    const run_lib_unit_tests = b.addRunArtifact(
        b.addTest(.{
            .root_module = lib_mod,
        }),
    );
    run_lib_unit_tests.skip_foreign_checks = true;
    test_step.dependOn(&run_lib_unit_tests.step);

    const doc = b.addObject(.{
        .name = "doc",
        .root_module = lib_mod,
    });
    const docs_install = b.addInstallDirectory(.{
        .source_dir = doc.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs_install.step);
}
