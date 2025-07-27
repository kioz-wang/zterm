const std = @import("std");

const Term = @import("Term");

const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const Self = @This();

const _cmd = Command.new("here").about("Test for report")
    .arg(Arg.optArg("tty", []const u8).long("tty"))
    .arg(Arg.optArg("at", ?Term.cursor.Vec2).long("at"))
    .arg(Arg.posArg("message", []const u8));
fn cb(args: *_cmd.Result()) void {
    var term = Term.new(
        std.fs.openFileAbsolute(
            args.tty,
            .{ .mode = .read_write },
        ) catch |e| zargs.exit(e, 1),
    );
    if (@import("builtin").target.os.tag == .windows) {
        term.print("unsupported\n", .{}) catch |e| zargs.exit(e, 1);
    } else {
        const posi = term.cursorPosition() catch |e| zargs.exit(e, 1);
        std.debug.print("cursor position: {}\n", .{posi});
        const winsz = term.windowSize() catch |e| zargs.exit(e, 1);
        std.debug.print("window size: {}\n", .{winsz});
        if (args.at) |at| {
            term.mvprint(.at(at), "{s}", .{args.message}) catch |e| zargs.exit(e, 1);
        } else {
            term.print("{s}", .{args.message}) catch |e| zargs.exit(e, 1);
        }
    }
}

pub const cmd = Self._cmd.callBack(Self.cb);
