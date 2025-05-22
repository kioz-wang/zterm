const std = @import("std");

pub const alias = struct {
    pub const String = []const u8;
    pub const LiteralString = [:0]const u8;
    pub const print = std.fmt.comptimePrint;
    pub const sprint = std.fmt.bufPrint;
    pub const FormatOptions = std.fmt.FormatOptions;
};

const String = alias.String;

pub const formatter = struct {
    const assert = std.debug.assert;
    pub fn any(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        return std.fmt.formatType(v, "any", .{}, writer, std.fmt.default_max_depth);
    }
    pub fn dInt(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        assert(@typeInfo(@TypeOf(v)) == .int);
        return std.fmt.formatIntValue(v, "d", .{}, writer);
    }
    pub fn dEnum(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        assert(@typeInfo(@TypeOf(v)) == .@"enum");
        return dInt(@intFromEnum(v), writer);
    }
    pub fn cEnum(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        assert(@typeInfo(@TypeOf(v)) == .@"enum");
        return std.fmt.formatIntValue(@intFromEnum(v), "c", .{}, writer);
    }
    pub fn Raw(T: type) type {
        return struct {
            v: T,
            pub fn format(self: @This(), comptime fmt: []const u8, options: alias.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
                try self.v.rawFormat(fmt, options, writer);
            }
        };
    }
    pub fn raw(v: anytype) Raw(@TypeOf(v)) {
        return .{ .v = v };
    }
};

pub const env = struct {
    pub fn flag(key: String) bool {
        const GetEnvVarOwnedError = std.process.GetEnvVarOwnedError;
        var Allocator = std.heap.DebugAllocator(.{}).init;
        const allocator = Allocator.allocator();
        const value = std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
            GetEnvVarOwnedError.EnvironmentVariableNotFound => return false,
            else => unreachable,
        };
        defer allocator.free(value);
        return value.len != 0;
    }
    pub fn Flag(key: anytype) type {
        std.debug.assert(@typeInfo(@TypeOf(key)) == .enum_literal);
        return struct {
            var value: ?bool = null;
            pub fn check() bool {
                if (value == null)
                    value = flag(@tagName(key));
                return value.?;
            }
            pub fn force(b: bool) void {
                value = b;
            }
        };
    }
};

pub fn cast(T: type, n: anytype) T {
    return @intCast(n);
}
pub fn castU(u: anytype) u32 {
    return cast(u32, u);
}
pub fn castI(i: anytype) i32 {
    return cast(i32, i);
}

pub fn Stringify(V: type) type {
    return struct {
        v: V,
        const Self = @This();
        pub fn count(self: Self) usize {
            var writer = std.io.countingWriter(std.io.null_writer);
            @setEvalBranchQuota(100000); // TODO why?
            self.v.stringify(writer.writer()) catch unreachable;
            return writer.bytes_written;
        }
        pub inline fn literal(self: Self) *const [self.count():0]u8 {
            comptime {
                var buf: [self.count():0]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buf);
                @setEvalBranchQuota(100000); // TODO why?
                self.v.stringify(fbs.writer()) catch unreachable;
                buf[buf.len] = 0;
                const final = buf;
                return &final;
            }
        }
    };
}
pub fn stringify(v: anytype) Stringify(@TypeOf(v)) {
    return .{ .v = v };
}
