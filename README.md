# zterm

A Zig implementation of [console_codes (4)](https://www.man7.org/linux/man-pages/man4/console_codes.4.html).

![asciicast](.asset/zterm_cli.gif)

## Features

- No memory allocator needed
- Generate attributes containing multiple styles (e.g. bold, italic) and colors (including foreground/background)
  - Comptime constructor
  - Use `.value(v)` to wrap any value for formatting, enforcing strict attribute handling (applied before output and reset after)
  - Use `.fprint(writer, fmt, args)` to incrementally apply an attribute before output
- Move cursor to/at a position
- Get the position of current cursor
- Support [`NO_COLOR`](https://no-color.org/) (also, support `NO_STYLE`!)
  - Check environments at runtime
  - Get literal string (ignore environments, comptime) by `toString()`
- Get window size

### Plans

> See [issues](https://github.com/kioz-wang/zterm/issues?q=is%3Aissue%20state%3Aopen%20label%3Aenhancement).

- [ ] Cross-platform: windows, macos
- [ ] Read the key, text, password and etc

### APIs

> See https://kioz-wang.github.io/zterm/#doc

## Installation

### fetch

Get the latest version:

```bash
zig fetch --save git+https://github.com/kioz-wang/zterm
```

To fetch a specific version (e.g., `v0.14.1`):

```bash
zig fetch --save https://github.com/kioz-wang/zterm/archive/refs/tags/v0.14.1.tar.gz
```

#### Version Notes

> See https://github.com/kioz-wang/zterm/releases

The version number follows the format `vx.y.z`:
- **x**: Currently fixed at 0. It will increment to 1 when the project stabilizes. Afterward, it will increment by 1 for any breaking changes.
- **y**: Represents the supported Zig version. For example, `vx.14.z` supports [Zig 0.14.0](https://github.com/ziglang/zig/releases/tag/0.14.0).
- **z**: Iteration version, where even numbers indicate releases with new features or significant changes (see [milestones](https://github.com/kioz-wang/zterm/milestones)), and odd numbers indicate releases with fixes or minor changes.

### import

Use `addImport` in your `build.zig` (e.g.):

```zig
const exe_mod = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});
exe_mod.addImport("Term", b.dependency("zterm", .{}).module("Term"));
const exe = b.addExecutable(.{
    .name = "your_app_name",
    .root_module = exe_mod,
});
exe.linkLibC();
b.installArtifact(exe);

const run_cmd = b.addRunArtifact(exe);
run_cmd.step.dependOn(b.getInstallStep());
if (b.args) |args| {
    run_cmd.addArgs(args);
}

const run_step = b.step("run", "Run the app");
run_step.dependOn(&run_cmd.step);
```

After importing the `Term`, you could get a terminal `getStd` by:

```zig
const term = @import("Term").getStd();
```

## Examples

See builtin demo: `zig build run -- -h`

> Welcome to submit PRs to link your project that use `zterm`!

More real-world examples are coming!

- emmm...

## License

[MIT](LICENSE) © Kioz Wang
