const std = @import("std");

const terminal = @import("Term").getStd();
const Attribute = @import("attr").Attribute;

const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const Self = @This();

const _cmd = Command.new("here").about("Test for report");
fn cb(_: *_cmd.Result()) void {
    const posi = terminal.report() catch |e| zargs.exit(e, 1);
    std.debug.print("{any}\n", .{posi});
}

pub const cmd = Self._cmd.callBack(Self.cb);
