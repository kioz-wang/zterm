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
    NotATerminal,
};

const Error = std.Io.Writer.Error || std.Io.Reader.Error || TermError;

fw: std.fs.File.Writer,
fr: std.fs.File.Reader,

const Self = @This();

pub fn new(file: std.fs.File) Error!Self {
    if (!file.getOrEnableAnsiEscapeSupport()) {
        return TermError.NotATerminal;
    }
    return .{ .fw = file.writerStreaming(&.{}), .fr = file.readerStreaming(&.{}) };
}
pub fn getStd() Error!Self {
    if (!std.fs.File.stdout().getOrEnableAnsiEscapeSupport()) {
        return TermError.NotATerminal;
    }
    return .{
        .fw = std.fs.File.stdout().writerStreaming(&.{}),
        .fr = std.fs.File.stdin().readerStreaming(&.{}),
    };
}

pub fn getCursor(self: *Self) cursor.Cursor {
    return .{ .w = &self.fw.interface };
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) Error!void {
    try self.fw.interface.print(fmt, args);
}
pub fn mvprint(self: *Self, mv: cursor.Point, comptime fmt: []const u8, args: anytype) Error!void {
    try self.getCursor().move(mv);
    try self.fw.interface.print(fmt, args);
}
pub fn aprint(self: *Self, a: attr.Attribute, comptime fmt: []const u8, args: anytype) Error!void {
    try a.fprint(&self.fw.interface, fmt, args);
}
pub fn mvaprint(self: *Self, mv: cursor.Point, a: attr.Attribute, comptime fmt: []const u8, args: anytype) Error!void {
    try self.getCursor().move(mv);
    try a.fprint(&self.fw.interface, fmt, args);
}

pub fn insertBlank(self: *Self, u: anytype) Error!void {
    if (u == 0) return;
    try F.ICH.param(&self.fw.interface, "{d}", .{castU(u)});
}
pub fn insertLine(self: *Self, u: anytype) Error!void {
    if (u == 0) return;
    try F.IL.param(&self.fw.interface, "{d}", .{castU(u)});
}
pub fn deleteLine(self: *Self, u: anytype) Error!void {
    if (u == 0) return;
    try F.DL.param(&self.fw.interface, "{d}", .{castU(u)});
}
pub fn deleteColumnAt(self: *Self, u: anytype) Error!void {
    try F.DCH.param(&self.fw.interface, "{d}", .{castU(u) + 1});
}
pub fn eraseLine(self: *Self, _el: ?par.EL) Error!void {
    if (_el) |el| {
        try F.EL.param(&self.fw.interface, "{d}", .{@intFromEnum(el)});
    } else {
        try F.EL.param(&self.fw.interface, "", .{});
    }
}
pub fn eraseDisplay(self: *Self, _ed: ?par.ED) Error!void {
    if (_ed) |ed| {
        try F.ED.param(&self.fw.interface, "{d}", .{@intFromEnum(ed)});
    } else {
        try F.ED.param(&self.fw.interface, "", .{});
    }
}
pub fn eraseColumnAt(self: *Self, u: anytype) Error!void {
    try F.ECH.param(&self.fw.interface, "{d}", .{castU(u) + 1});
}
pub fn keyboardLED(self: *Self, led: par.DECLL) Error!void {
    try F.DECLL.param(&self.fw.interface, "{d}", .{@intFromEnum(led)});
}
pub fn mode(self: *Self, m: par.SM, set: bool) Error!void {
    const f = if (set) F.SM else F.RM;
    try f.param(&self.fw.interface, "{d}", .{@intFromEnum(m)});
}

/// TODO: When open another `tty`, sometimes report without prefixed `0x1b`, why?
pub fn cursorPosition(self: *Self) !cursor.Vec2 {
    var buffer: [32]u8 = undefined;

    const old = try std.posix.tcgetattr(self.fr.file.handle);
    var raw = old;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    try std.posix.tcsetattr(self.fr.file.handle, .NOW, raw);
    defer std.posix.tcsetattr(self.fr.file.handle, .NOW, old) catch unreachable;

    try F.DSR.param(&self.fw.interface, "{d}", .{@intFromEnum(par.DSR.CPR)});
    // const count = try self.fr.read(&buffer); TODO why?
    const count = try self.fr.readStreaming(&buffer);
    var slice = std.mem.trimEnd(u8, buffer[0..count], "\n");

    const prefix = std.fmt.comptimePrint("{f}", .{ctl.ESCSequence.CSI});
    if (std.mem.startsWith(u8, slice, prefix) and slice[slice.len - 1] == 'R') {
        const s = slice[0 .. slice.len - 1][prefix.len..];
        var i = std.mem.splitAny(u8, s, ";");
        const row = try std.fmt.parseInt(i32, i.next().?, 10);
        const col = try std.fmt.parseInt(i32, i.next().?, 10);
        return .{ col - 1, row - 1 };
    }
    return Error.InvalidReport;
    // std.debug.panic("invalid report: {d}:_{x}_", .{ slice.len, slice });
}

pub fn windowSize(self: *Self) !cursor.Vec2 {
    var w: std.posix.winsize = undefined;
    const ret = std.c.ioctl(self.fr.file.handle, std.c.T.IOCGWINSZ, &w);
    if (ret != 0) {
        return Error.InvalidReport;
    }
    return .{ w.col, w.row };
}

test "NotATerminal" {
    try std.testing.expectError(TermError.NotATerminal, getStd());
}
