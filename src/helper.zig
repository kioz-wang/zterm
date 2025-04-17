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
const LiteralString = Alias.LiteralString;
const print = Alias.print;
const sprint = Alias.sprint;
const FormatOptions = Alias.FormatOptions;

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
};
