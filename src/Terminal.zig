const std = @import("std");
const par = @import("mapping").par;
const ctl = @import("mapping").ctl;
const F = @import("mapping").F;
pub const attr = @import("attr");
pub const cursor = @import("cursor");
const castU = @import("helper").castU;
const castI = @import("helper").castI;

const TermError = error{
    InvalidReport,
};

const W = std.fs.File.Writer;
const R = std.fs.File.Reader;
const Error = W.Error || R.Error || TermError;

w: W,
r: R,

const Self = @This();

pub fn new(file: std.fs.File) Self {
    return .{ .w = file.writer(), .r = file.reader() };
}
pub fn getStd() Self {
    return .{
        .w = std.io.getStdOut().writer(),
        .r = std.io.getStdIn().reader(),
    };
}

pub fn print(self: Self, comptime fmt: []const u8, args: anytype) Error!void {
    try self.w.print(fmt, args);
}
pub fn posiPrint(self: Self) cursor.PosiPrinter(Self) {
    return .new(self);
}
pub fn getAttror(self: Self, attribute: attr.Attribute) attr.AttrWriter(W) {
    return .new(attribute, self.w);
}
pub fn getCursor(self: Self) cursor.CursorWriter(W) {
    return .new(self.w);
}

pub fn insertBlank(self: Self, u: anytype) Error!void {
    if (u == 0) return;
    try F.ICH.param(self.w, "{d}", .{castU(u)});
}
pub fn insertLine(self: Self, u: anytype) Error!void {
    if (u == 0) return;
    try F.IL.param(self.w, "{d}", .{castU(u)});
}
pub fn deleteLine(self: Self, u: anytype) Error!void {
    if (u == 0) return;
    try F.DL.param(self.w, "{d}", .{castU(u)});
}
pub fn deleteColumnAt(self: Self, u: anytype) Error!void {
    try F.DCH.param(self.w, "{d}", .{castU(u) + 1});
}
pub fn eraseLine(self: Self, _el: ?par.EL) Error!void {
    if (_el) |el| {
        try F.EL.param(self.w, "{d}", .{@intFromEnum(el)});
    } else {
        try F.EL.param(self.w, "", .{});
    }
}
pub fn eraseDisplay(self: Self, _ed: ?par.ED) Error!void {
    if (_ed) |ed| {
        try F.ED.param(self.w, "{d}", .{@intFromEnum(ed)});
    } else {
        try F.ED.param(self.w, "", .{});
    }
}
pub fn eraseColumnAt(self: Self, u: anytype) Error!void {
    try F.ECH.param(self.w, "{d}", .{castU(u) + 1});
}
pub fn keyboardLED(self: Self, led: par.DECLL) Error!void {
    try F.DECLL.param(self.w, "{d}", .{@intFromEnum(led)});
}
pub fn mode(self: Self, m: par.SM, set: bool) Error!void {
    const f = if (set) F.SM else F.RM;
    try f.param(self.w, "{d}", .{@intFromEnum(m)});
}

/// TODO: When open another `tty`, sometimes report without prefixed `0x1b`, why?
pub fn cursorPosition(self: Self) !cursor.Vec2 {
    var buffer: [32]u8 = undefined;
    var slice: []const u8 = undefined;

    const old = try std.posix.tcgetattr(self.r.context.handle);
    var raw = old;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    try std.posix.tcsetattr(self.r.context.handle, .NOW, raw);
    defer std.posix.tcsetattr(self.r.context.handle, .NOW, old) catch unreachable;

    try F.DSR.param(self.w, "{d}", .{@intFromEnum(par.DSR.CPR)});
    slice = std.mem.trimRight(u8, buffer[0..(try self.r.read(&buffer))], "\n");

    const prefix = std.fmt.comptimePrint("{}", .{ctl.ESCSequence.CSI});
    if (std.mem.startsWith(u8, slice, prefix) and slice[slice.len - 1] == 'R') {
        const s = slice[0 .. slice.len - 1][prefix.len..];
        var i = std.mem.splitAny(u8, s, ";");
        const row = try std.fmt.parseInt(i32, i.next().?, 10);
        const col = try std.fmt.parseInt(i32, i.next().?, 10);
        return .{ col - 1, row - 1 };
    }
    return Error.InvalidReport;
    // std.debug.panic("invalid report: {d}:_{s}_", .{ slice.len, slice });
}

pub fn windowSize(self: Self) !cursor.Vec2 {
    var w: std.posix.winsize = undefined;
    const ret = std.c.ioctl(self.r.context.handle, std.c.T.IOCGWINSZ, &w);
    if (ret != 0) {
        return Error.InvalidReport;
    }
    return .{ w.col, w.row };
}
