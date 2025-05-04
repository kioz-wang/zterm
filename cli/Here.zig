const std = @import("std");

const Term = @import("Term");

const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const Self = @This();

const WrapperVec2 = struct {
    value: Term.cursor.Vec2,
    const default: WrapperVec2 = .{ .value = Term.cursor.origin };
    pub fn parse(s: []const u8, _: ?std.mem.Allocator) ?WrapperVec2 {
        return .{ .value = Term.cursor.parseVec2(s, null) orelse return null };
    }
};

const _cmd = Command.new("here").about("Test for report")
    .arg(Arg.optArg("tty", []const u8).long("tty"))
    .arg(Arg.optArg("at", ?WrapperVec2).long("at"))
    .arg(Arg.posArg("message", []const u8));
fn cb(args: *_cmd.Result()) void {
    const term = Term.new(
        std.fs.openFileAbsolute(
            args.tty,
            .{ .mode = .read_write },
        ) catch |e| zargs.exit(e, 1),
    );
    const posi = term.cursorPosition() catch |e| zargs.exit(e, 1);
    std.debug.print("cursor position: {}\n", .{posi});
    const winsz = term.windowSize() catch |e| zargs.exit(e, 1);
    std.debug.print("window size: {}\n", .{winsz});
    if (args.at) |at| {
        term.posiPrint().at(at.value, "{s}", .{args.message}) catch |e| zargs.exit(e, 1);
    } else {
        term.print("{s}", .{args.message}) catch |e| zargs.exit(e, 1);
    }
}

pub const cmd = Self._cmd.callBack(Self.cb);
