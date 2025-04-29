const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_helper = b.createModule(.{
        .root_source_file = b.path("src/helper.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_mapping = b.createModule(.{
        .root_source_file = b.path("src/mapping/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod_mapping.addImport("helper", mod_helper);

    const mod_cursor = b.createModule(.{
        .root_source_file = b.path("src/cursor.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod_cursor.addImport("mapping", mod_mapping);
    mod_cursor.addImport("helper", mod_helper);

    const mod_attr = b.addModule("attr", .{
        .root_source_file = b.path("src/attr.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod_attr.addImport("helper", mod_helper);
    mod_attr.addImport("mapping", mod_mapping);
    mod_attr.addImport("cursor", mod_cursor);

    const mod_term = b.addModule("Term", .{
        .root_source_file = b.path("src/Terminal.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod_term.addImport("mapping", mod_mapping);
    mod_term.addImport("attr", mod_attr);
    mod_term.addImport("cursor", mod_cursor);

    const test_step = b.step("test", "Run unit tests");
    const files_contain_ut = [_]*std.Build.Module{ mod_attr, mod_mapping };
    for (files_contain_ut) |file_ut| {
        const run_ut = b.addRunArtifact(
            b.addTest(.{ .root_module = file_ut }),
        );
        run_ut.skip_foreign_checks = true;
        test_step.dependOn(&run_ut.step);
    }

    const doc = b.addObject(.{
        .name = "doc",
        .root_module = mod_term,
    });
    const docs_install = b.addInstallDirectory(.{
        .source_dir = doc.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs_install.step);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("Term", mod_term);
    exe_mod.addImport("attr", mod_attr);
    exe_mod.addImport("zargs", b.dependency("zargs", .{}).module("zargs"));

    const exe = b.addExecutable(.{
        .name = "zterm_cli",
        .root_module = exe_mod,
    });
    exe.linkLibC();
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run CLI demo");
    run_step.dependOn(&run_cmd.step);
}
