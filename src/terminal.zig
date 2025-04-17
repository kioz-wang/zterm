const std = @import("std");
const parameter = @import("parameter.zig");
const attribute = @import("attribute.zig");
const Attribute = attribute.Attribute;
const AttrWriter = attribute.AttrWriter;
const CursorWriter = @import("cursor.zig").CursorWriter;
const PosiWriter = @import("cursor.zig").PosiWriter;
const F = @import("control.zig").CSISequenceFunction;

pub fn apply(w: anytype) TermWriter(@TypeOf(w)) {
    return .new(w);
}

pub fn TermWriter(W: type) type {
    return struct {
        inner: W,

        const Self = @This();

        pub fn new(writer: W) Self {
            return .{ .inner = writer };
        }
        pub fn attributor(self: Self, attr: Attribute) AttrWriter(W) {
            return .new(attr, self.inner);
        }
        pub fn cursor(self: Self) CursorWriter(W) {
            return .new(self.inner);
        }
        pub fn positioner(self: Self) PosiWriter(Self) {
            return .new(self);
        }

        pub fn print(self: Self, comptime fmt: []const u8, args: anytype) W.Error!void {
            try self.inner.print(fmt, args);
        }

        pub fn insertBlank(self: Self, n: u32) W.Error!void {
            try F.ICH.param(self.inner, "{d}", .{n});
        }
        pub fn insertLine(self: Self, n: u32) W.Error!void {
            try F.IL.param(self.inner, "{d}", .{n});
        }
        pub fn deleteLine(self: Self, n: u32) W.Error!void {
            try F.DL.param(self.inner, "{d}", .{n});
        }
        pub fn deleteColumnAt(self: Self, n: u32) W.Error!void {
            try F.DCH.param(self.inner, "{d}", .{n});
        }
        pub fn eraseLine(self: Self, _el: ?parameter.EL) W.Error!void {
            if (_el) |el| {
                try F.EL.param(self.inner, "{d}", .{@intFromEnum(el)});
            } else {
                try F.EL.param(self.inner, "", .{});
            }
        }
        pub fn eraseDisplay(self: Self, _ed: ?parameter.ED) W.Error!void {
            if (_ed) |ed| {
                try F.ED.param(self.inner, "{d}", .{@intFromEnum(ed)});
            } else {
                try F.ED.param(self.inner, "", .{});
            }
        }
        pub fn eraseColumnAt(self: Self, n: u32) W.Error!void {
            try F.ECH.param(self.inner, "{d}", .{n});
        }
        pub fn keyboardLED(self: Self, led: parameter.DECLL) W.Error!void {
            try F.DECLL.param(self.inner, "{d}", .{@intFromEnum(led)});
        }
        pub fn mode(self: Self, m: parameter.SM, set: bool) W.Error!void {
            const f = if (set) F.SM else F.RM;
            try f.param(self.inner, "{d}", .{@intFromEnum(m)});
        }
    };
}
