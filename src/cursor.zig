const std = @import("std");
const F = @import("mapping").F;
const castU = @import("helper").castU;
const castI = @import("helper").castI;
const assert = std.debug.assert;

pub const Vec2 = @Vector(2, i32);
pub const origin: Vec2 = .{ 0, 0 };

pub fn castVec2(x: anytype, y: anytype) Vec2 {
    return .{ @intCast(x), @intCast(y) };
}
/// `( 1,0)`, `{2,-2}`, `( 2 ; -6)`, `(2: 3)`
pub fn parseVec2(s: []const u8, _: ?std.mem.Allocator) ?Vec2 {
    const ss = std.mem.trim(u8, s, "(){} ");
    var i = std.mem.splitAny(u8, ss, ";,:");
    const sx = i.next() orelse return null;
    const x = std.fmt.parseInt(i32, std.mem.trim(u8, sx, " "), 0) catch return null;
    const sy = i.next() orelse return null;
    const y = std.fmt.parseInt(i32, std.mem.trim(u8, sy, " "), 0) catch return null;
    if (i.next() != null) return null;
    return .{ x, y };
}
pub fn scaleVec2(raw: Vec2, scale: Vec2) ?Vec2 {
    const x = @mulWithOverflow(raw[0], scale[0]);
    if (x[1] != 0) return null;
    const y = @mulWithOverflow(raw[1], scale[1]);
    if (x[1] != 0) return null;
    return .{ x[0], y[0] };
}

const _test = struct {
    const t = std.testing;
    test "Cast" {
        try t.expectEqual(Vec2{ 1, -2 }, castVec2(@as(u16, 1), @as(i64, -2)));
    }
    test "Parse" {
        try t.expectEqual(Vec2{ 10, -2 }, parseVec2("(10,-2)", null));
        try t.expectEqual(Vec2{ 10, -2 }, parseVec2("{10,-2}", null));
        try t.expectEqual(Vec2{ 10, -2 }, parseVec2("(10 , -2)", null));
        try t.expectEqual(Vec2{ 10, -2 }, parseVec2("( 10 ;-2)", null));
        try t.expectEqual(Vec2{ 10, -2 }, parseVec2("( 0xa : -2  )", null));
    }
};

pub const Region = union(enum) {
    quad1,
    quad2,
    quad3,
    quad4,
    axisX: bool,
    axisY: bool,
    origin,

    pub fn get(point: Vec2) Region {
        const x, const y = point;
        return if (x > 0 and y == 0) .{ .axisX = true } else if (x > 0 and y > 0) .quad1 else if (x == 0 and y > 0) .{ .axisY = true } else if (x < 0 and y > 0) .quad2 else if (x < 0 and y == 0) .{ .axisX = false } else if (x < 0 and y < 0) .quad3 else if (x == 0 and y < 0) .{ .axisY = false } else if (x > 0 and y < 0) .quad4 else .origin;
    }

    const _test = struct {
        const t = std.testing;
        test "Region check" {
            try t.expect(get(.{ 1, 0 }).axisX);
            try t.expect(get(.{ 1, 1 }) == .quad1);
            try t.expect(get(.{ 0, 1 }).axisY);
            try t.expect(get(.{ -1, 1 }) == .quad2);
            try t.expect(!get(.{ -1, 0 }).axisX);
            try t.expect(get(.{ -1, -1 }) == .quad3);
            try t.expect(!get(.{ 0, -1 }).axisY);
            try t.expect(get(.{ 1, -1 }) == .quad4);
        }
    };
};

pub fn CursorWriter(W: type) type {
    return struct {
        w: W,

        const Self = @This();
        pub const Error = W.Error;

        pub fn new(writer: W) Self {
            return .{ .w = writer };
        }

        pub fn up(self: Self, u: anytype) Error!void {
            if (u == 0) return;
            try F.CUU.param(self.w, "{d}", .{castU(u)});
        }
        pub fn down(self: Self, u: anytype) Error!void {
            if (u == 0) return;
            // same as `F.VPR`
            try F.CUD.param(self.w, "{d}", .{castU(u)});
        }
        pub fn right(self: Self, u: anytype) Error!void {
            if (u == 0) return;
            // same as `F.HPR`
            try F.CUF.param(self.w, "{d}", .{castU(u)});
        }
        pub fn left(self: Self, u: anytype) Error!void {
            if (u == 0) return;
            try F.CUB.param(self.w, "{d}", .{castU(u)});
        }

        /// when u == 0?, columnAt(0)
        pub fn upBegin(self: Self, u: anytype) Error!void {
            try F.CPL.param(self.w, "{d}", .{castU(u)});
        }
        pub fn downBegin(self: Self, u: anytype) Error!void {
            try F.CNL.param(self.w, "{d}", .{castU(u)});
        }

        pub fn columnAt(self: Self, u: anytype) Error!void {
            // same as `F.HPA`
            try F.CHA.param(self.w, "{d}", .{castU(u) + 1});
        }
        pub fn rowAt(self: Self, u: anytype) Error!void {
            try F.VPA.param(self.w, "{d}", .{castU(u) + 1});
        }
        pub fn moveAt(self: Self, point: Vec2) Error!void {
            assert(Region.get(point + Vec2{ 1, 1 }) == .quad1);
            // same as `F.HVP`
            try F.CUP.param(self.w, "{d}{c}{d}", .{
                castU(point[1]) + 1,
                @import("mapping").par.sep,
                castU(point[0]) + 1,
            });
        }

        pub fn save(self: Self) Error!void {
            try F.CUS.param(self.w, "", .{});
        }
        pub fn restore(self: Self) Error!void {
            try F.CUR.param(self.w, "", .{});
        }

        pub fn row(self: Self, _i: anytype) Error!void {
            const i = castI(_i);
            if (i == 0) return;
            if (i > 0) {
                try self.down(i);
            } else {
                try self.up(-i);
            }
        }
        pub fn column(self: Self, _i: anytype) Error!void {
            const i = castI(_i);
            if (i == 0) return;
            if (i > 0) {
                try self.right(i);
            } else {
                try self.left(-i);
            }
        }
        pub fn move(self: Self, vector: Vec2) Error!void {
            try self.row(vector[1]);
            try self.column(vector[0]);
        }
    };
}
pub fn cursorWriter(w: anytype) CursorWriter(@TypeOf(w)) {
    return .new(w);
}

pub fn PosiPrinter(W: type) type {
    comptime assert(@hasDecl(W, "print"));
    comptime assert(@hasField(W, "w"));
    return struct {
        w: W,
        const Self = @This();

        pub fn new(writer: W) Self {
            return .{ .w = writer };
        }
        pub fn to(self: Self, vector: Vec2, comptime fmt: []const u8, args: anytype) !void {
            try cursorWriter(self.w.w).move(vector);
            try self.w.print(fmt, args);
        }
        pub fn at(self: Self, point: Vec2, comptime fmt: []const u8, args: anytype) !void {
            try cursorWriter(self.w.w).moveAt(point);
            try self.w.print(fmt, args);
        }
    };
}
pub fn posiPrinter(w: anytype) PosiPrinter(@TypeOf(w)) {
    return .new(w);
}

test {
    _ = Region._test;
    _ = _test;
}
