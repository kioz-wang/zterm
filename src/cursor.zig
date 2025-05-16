const std = @import("std");
const F = @import("mapping").F;

/// Point or vector in a planar coordinate
pub const Vec2 = @Vector(2, i32);
pub const origin: Vec2 = .{ 0, 0 };

/// Construct from any int type
pub fn castVec2(x: anytype, y: anytype) Vec2 {
    return .{ @intCast(x), @intCast(y) };
}
/// Scale `raw` with `scale`, return a new `Vec2`
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

pub const Row = union(enum) {
    _up: u32,
    _down: u32,
    _at: u32,
    stay,
    const Self = @This();
    pub fn up(i: anytype) Self {
        return if (i == 0) .stay else .{ ._up = @intCast(i) };
    }
    pub fn down(i: anytype) Self {
        return if (i == 0) .stay else .{ ._down = @intCast(i) };
    }
    pub fn at(i: anytype) Self {
        return .{ ._at = @intCast(i) };
    }
    pub fn rel(i: anytype) Self {
        return if (i > 0) down(i) else up(-i);
    }
};
pub const Column = union(enum) {
    _left: u32,
    _right: u32,
    _at: u32,
    stay,
    const Self = @This();
    pub fn left(i: anytype) Self {
        return if (i == 0) .stay else .{ ._left = @intCast(i) };
    }
    pub fn right(i: anytype) Self {
        return if (i == 0) .stay else .{ ._right = @intCast(i) };
    }
    pub fn at(i: anytype) Self {
        return .{ ._at = @intCast(i) };
    }
    pub fn rel(i: anytype) Self {
        return if (i > 0) right(i) else left(-i);
    }
};
pub const Point = union(enum) {
    _rel: Vec2,
    _at: Vec2,
    stay,
    const Self = @This();
    pub fn at(p: Vec2) Self {
        std.debug.assert(Region.get(p + Vec2{ 1, 1 }) == .quad1);
        return .{ ._at = p };
    }
    pub fn rel(p: Vec2) Self {
        return if (p == origin) .stay else .{ ._rel = p };
    }
};

pub fn Cursor(W: type) type {
    return struct {
        w: W,

        const Self = @This();
        pub const Error = W.Error;

        pub fn new(writer: W) Self {
            return .{ .w = writer };
        }

        pub fn save(self: Self) Error!void {
            try F.CUS.param(self.w, "", .{});
        }
        pub fn restore(self: Self) Error!void {
            try F.CUR.param(self.w, "", .{});
        }

        pub fn beginRow(self: Self, n: Row) Error!void {
            switch (n) {
                .stay => try self.column(.at(0)),
                ._up => |i| try F.CPL.param(self.w, "{d}", .{i}),
                ._down => |i| try F.CNL.param(self.w, "{d}", .{i}),
                ._at => |i| try self.move(.at(castVec2(0, i))),
            }
        }
        pub fn row(self: Self, n: Row) Error!void {
            switch (n) {
                .stay => return,
                ._up => |i| try F.CUU.param(self.w, "{d}", .{i}),
                // same as `F.VPR`
                ._down => |i| try F.CUD.param(self.w, "{d}", .{i}),
                ._at => |i| try F.VPA.param(self.w, "{d}", .{i + 1}),
            }
        }
        pub fn column(self: Self, n: Column) Error!void {
            switch (n) {
                .stay => return,
                ._left => |i| try F.CUF.param(self.w, "{d}", .{i}),
                // same as `F.HPR`
                ._right => |i| try F.CUB.param(self.w, "{d}", .{i}),
                // same as `F.HPA`
                ._at => |i| try F.CHA.param(self.w, "{d}", .{i + 1}),
            }
        }
        pub fn move(self: Self, p: Point) Error!void {
            const sep = @import("mapping").par.sep;
            switch (p) {
                .stay => return,
                ._rel => |v| {
                    try self.row(.rel(v[1]));
                    try self.column(.rel(v[0]));
                },
                ._at => |v|
                // same as `F.HVP`
                try F.CUP.param(self.w, "{d}{c}{d}", .{
                    @as(u32, @intCast(v[1])) + 1,
                    sep,
                    @as(u32, @intCast(v[0])) + 1,
                }),
            }
        }
    };
}
pub fn cursor(w: anytype) Cursor(@TypeOf(w)) {
    return .new(w);
}

test {
    _ = Region._test;
    _ = _test;
}
