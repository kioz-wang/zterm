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

    const mod_cursor = b.addModule("cursor", .{
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
    mod_term.addImport("helper", mod_helper);
    mod_term.addImport("mapping", mod_mapping);
    mod_term.addImport("attr", mod_attr);
    mod_term.addImport("cursor", mod_cursor);

    const test_step = b.step("test", "Run unit tests");
    const test_filters: []const []const u8 = b.option(
        []const []const u8,
        "test_filter",
        "Skip tests that do not match any of the specified filters",
    ) orelse &.{};
    const mods_utest = [_]*std.Build.Module{ mod_helper, mod_attr, mod_mapping, mod_cursor };
    for (mods_utest) |unit| {
        const utest = b.addRunArtifact(
            b.addTest(.{
                .root_module = unit,
                .filters = test_filters,
            }),
        );
        utest.skip_foreign_checks = true;
        test_step.dependOn(&utest.step);
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
}
