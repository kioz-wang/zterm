const std = @import("std");

const Term = @import("Term");

const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const Self = @This();

const _cmd = Command.new("here").about("Test for report")
    .arg(Arg.optArg("tty", []const u8).long("tty"));
fn cb(args: *_cmd.Result()) void {
    const term = Term.new(
        std.fs.openFileAbsolute(
            args.tty,
            .{ .mode = .read_write },
        ) catch |e| zargs.exit(e, 1),
    );
    const posi = term.reportCursor() catch |e| zargs.exit(e, 1);
    std.debug.print("{}\n", .{posi});
}

pub const cmd = Self._cmd.callBack(Self.cb);
