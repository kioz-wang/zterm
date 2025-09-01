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
    pub fn any(v: anytype, writer: *std.io.Writer) std.io.Writer.Error!void {
        const actual_fmt = switch (@typeInfo(@TypeOf(v))) {
            .array, .vector, .optional, .error_union => "any",
            .pointer => |ptr_info| switch (ptr_info.size) {
                .one => switch (@typeInfo(ptr_info.child)) {
                    .array => "any",
                    else => "",
                },
                .many, .c => "*",
                .slice => "any",
            },
            else => "",
        };
        if (comptime std.mem.eql(u8, actual_fmt, "*")) {
            return writer.printAddress(v, .{});
        }
        if (std.meta.hasMethod(@TypeOf(v), "format")) {
            return try v.format(writer);
        }
        return writer.printValue(actual_fmt, .{}, v, std.fmt.default_max_depth);
    }
    pub fn dInt(v: anytype, writer: *std.io.Writer) std.io.Writer.Error!void {
        assert(@typeInfo(@TypeOf(v)) == .int);
        return writer.printIntAny(v, 10, .lower, .{});
    }
    pub fn dEnum(v: anytype, writer: *std.io.Writer) std.io.Writer.Error!void {
        assert(@typeInfo(@TypeOf(v)) == .@"enum");
        return dInt(@intFromEnum(v), writer);
    }
    pub fn cEnum(v: anytype, writer: *std.io.Writer) std.io.Writer.Error!void {
        assert(@typeInfo(@TypeOf(v)) == .@"enum");
        return writer.printAsciiChar(@intFromEnum(v), .{});
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
            var counting = std.Io.Writer.Discarding.init(&@as([0]u8, .{}));
            @setEvalBranchQuota(100000); // TODO why?
            self.v.stringify(&counting.writer) catch unreachable;
            return counting.fullCount();
        }
        pub inline fn literal(self: Self) *const [self.count():0]u8 {
            comptime {
                var buf: [self.count():0]u8 = undefined;
                var fbs = std.Io.Writer.fixed(&buf);
                @setEvalBranchQuota(100000); // TODO why?
                self.v.stringify(&fbs) catch unreachable;
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
