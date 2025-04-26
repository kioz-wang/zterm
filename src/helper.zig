const std = @import("std");
const assert = std.debug.assert;

pub const Alias = struct {
    pub const String = []const u8;
    pub const LiteralString = [:0]const u8;
    pub const print = std.fmt.comptimePrint;
    pub const sprint = std.fmt.bufPrint;
    pub const FormatOptions = std.fmt.FormatOptions;
};

const String = Alias.String;

pub const Formatter = struct {
    pub fn anyFormat(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        return std.fmt.formatType(v, "any", .{}, writer, std.fmt.default_max_depth);
    }
    pub fn intFormat_d(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        assert(@typeInfo(@TypeOf(v)) == .int);
        return std.fmt.formatIntValue(v, "d", .{}, writer);
    }
    pub fn enumFormat_d(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        assert(@typeInfo(@TypeOf(v)) == .@"enum");
        return intFormat_d(@intFromEnum(v), writer);
    }
    pub fn enumFormat_c(v: anytype, writer: anytype) @TypeOf(writer).Error!void {
        assert(@typeInfo(@TypeOf(v)) == .@"enum");
        return std.fmt.formatIntValue(@intFromEnum(v), "c", .{}, writer);
    }
    pub fn RawFormatter(T: type) type {
        return struct {
            v: T,
            pub fn format(self: @This(), comptime fmt: []const u8, options: Alias.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
                try self.v.rawFormat(fmt, options, writer);
            }
        };
    }
    pub fn rawFormatter(v: anytype) RawFormatter(@TypeOf(v)) {
        return .{ .v = v };
    }
};

pub const Env = struct {
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
    /// cache flag
    pub fn Flag(key: String) type {
        return struct {
            var value: ?bool = null;
            pub fn check() bool {
                if (value == null)
                    value = flag(key);
                return value.?;
            }
        };
    }
};
