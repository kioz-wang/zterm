const F = @import("mapping").F;

pub fn apply(w: anytype) CursorWriter(@TypeOf(w)) {
    return .new(w);
}

pub fn CursorWriter(W: type) type {
    return struct {
        const Self = @This();
        inner: W,

        pub fn new(writer: W) Self {
            return .{ .inner = writer };
        }
        pub fn up(self: Self, n: u32) W.Error!void {
            try F.CUU.param(self.inner, "{d}", .{n});
        }
        pub fn down(self: Self, n: u32) W.Error!void {
            // same as `F.VPR`
            try F.CUD.param(self.inner, "{d}", .{n});
        }
        pub fn right(self: Self, n: u32) W.Error!void {
            // same as `F.HPR`
            try F.CUF.param(self.inner, "{d}", .{n});
        }
        pub fn left(self: Self, n: u32) W.Error!void {
            try F.CUB.param(self.inner, "{d}", .{n});
        }
        pub fn upBegin(self: Self, n: u32) W.Error!void {
            try F.CPL.param(self.inner, "{d}", .{n});
        }
        pub fn downBegin(self: Self, n: u32) W.Error!void {
            try F.CNL.param(self.inner, "{d}", .{n});
        }
        pub fn columnAt(self: Self, n: u32) W.Error!void {
            // same as `F.HPA`
            try F.CHA.param(self.inner, "{d}", .{n});
        }
        pub fn rowAt(self: Self, n: u32) W.Error!void {
            try F.VPA.param(self.inner, "{d}", .{n});
        }
        pub fn moveAt(self: Self, _row: u32, _column: u32) W.Error!void {
            // same as `F.HVP`
            try F.CUP.param(self.inner, "{d}{c}{d}", .{ _row, @import("mapping").par.sep, _column });
        }
        pub fn save(self: Self) W.Error!void {
            try F.CUS.param(self.inner, "", .{});
        }
        pub fn restore(self: Self) W.Error!void {
            try F.CUR.param(self.inner, "", .{});
        }

        pub fn row(self: Self, n: i32) W.Error!void {
            if (n == 0) return;
            if (n > 0) {
                try self.down(@intCast(n));
            } else {
                try self.up(@intCast(-n));
            }
        }
        pub fn column(self: Self, n: i32) W.Error!void {
            if (n == 0) return;
            if (n > 0) {
                try self.right(@intCast(n));
            } else {
                try self.left(@intCast(-n));
            }
        }
        pub fn move(self: Self, _row: i32, _column: i32) W.Error!void {
            try self.row(_row);
            try self.column(_column);
        }
    };
}

pub fn PosiWriter(CW: type) type {
    const W = @FieldType(CW, "inner");
    return struct {
        const Self = @This();
        writer: CW,

        pub fn new(writer: CW) Self {
            return .{ .writer = writer };
        }
        pub fn printRel(self: Self, row: i32, column: i32, comptime fmt: []const u8, args: anytype) W.Error!void {
            try CursorWriter(W).new(self.writer.inner).move(row, column);
            try self.writer.print(fmt, args);
        }
        pub fn printAbs(self: Self, row: u32, column: u32, comptime fmt: []const u8, args: anytype) W.Error!void {
            try CursorWriter(W).new(self.writer.inner).moveAt(row, column);
            try self.writer.print(fmt, args);
        }
    };
}
