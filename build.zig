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
    const files_contain_ut = [_][]const u8{ "src/attribute.zig", "src/parameter.zig" };
    for (files_contain_ut) |file_ut| {
        const run_ut = b.addRunArtifact(
            b.addTest(.{ .root_source_file = b.path(file_ut) }),
        );
        run_ut.skip_foreign_checks = true;
        test_step.dependOn(&run_ut.step);
    }

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
