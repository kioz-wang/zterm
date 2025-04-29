const std = @import("std");
const par = @import("mapping").par;
const F = @import("mapping").F;
const Attribute = @import("attr").Attribute;
const AttrWriter = @import("attr").AttrWriter;
const CursorWriter = @import("cursor").CursorWriter;
const PosiPrinter = @import("cursor").PosiPrinter;

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

pub fn attributor(self: Self, attr: Attribute) AttrWriter(W) {
    return .new(attr, self.w);
}
pub fn cursor(self: Self) CursorWriter(W) {
    return .new(self.w);
}

pub fn print(self: Self, comptime fmt: []const u8, args: anytype) Error!void {
    try self.w.print(fmt, args);
}
pub fn posiPrint(self: Self) PosiPrinter(Self) {
    return .new(self);
}
pub fn report(self: Self) !struct { u32, u32 } {
    var buffer: [32]u8 = undefined;
    var slice: []const u8 = undefined;

    const original = try std.posix.tcgetattr(self.r.context.handle);
    var raw = original;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    try std.posix.tcsetattr(self.r.context.handle, .NOW, raw);

    try F.DSR.param(self.w, "{d}", .{@intFromEnum(par.DSR.CPR)});
    slice = std.mem.trimRight(u8, buffer[0..(try self.r.read(&buffer))], "\n");

    try std.posix.tcsetattr(self.r.context.handle, .NOW, original);

    if (std.mem.startsWith(u8, slice, "\x1b[") and slice[slice.len - 1] == 'R') {
        const s = slice[0 .. slice.len - 1][2..];
        var i = std.mem.splitAny(u8, s, ";");
        const row: u32 = try std.fmt.parseInt(u32, i.next().?, 10);
        const col: u32 = try std.fmt.parseInt(u32, i.next().?, 10);
        return .{ row, col };
    }
    return Error.InvalidReport;
}

pub fn insertBlank(self: Self, n: u32) Error!void {
    try F.ICH.param(self.w, "{d}", .{n});
}
pub fn insertLine(self: Self, n: u32) Error!void {
    try F.IL.param(self.w, "{d}", .{n});
}
pub fn deleteLine(self: Self, n: u32) Error!void {
    try F.DL.param(self.w, "{d}", .{n});
}
pub fn deleteColumnAt(self: Self, n: u32) Error!void {
    try F.DCH.param(self.w, "{d}", .{n});
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
pub fn eraseColumnAt(self: Self, n: u32) Error!void {
    try F.ECH.param(self.w, "{d}", .{n});
}
pub fn keyboardLED(self: Self, led: par.DECLL) Error!void {
    try F.DECLL.param(self.w, "{d}", .{@intFromEnum(led)});
}
pub fn mode(self: Self, m: par.SM, set: bool) Error!void {
    const f = if (set) F.SM else F.RM;
    try f.param(self.w, "{d}", .{@intFromEnum(m)});
}
