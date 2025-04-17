const std = @import("std");
const helper = @import("helper.zig");
const print = helper.Alias.print;
const LiteralString = helper.Alias.LiteralString;
const FormatOptions = helper.Alias.FormatOptions;
const anyFormat = helper.Formatter.anyFormat;
const intFormat_d = helper.Formatter.intFormat_d;
const enumFormat_d = helper.Formatter.enumFormat_d;
const parameter = @import("parameter.zig");
const SGR = parameter.SGR;
const control = @import("control.zig");

pub const Style = struct {
    const Self = @This();
    const Storage = packed struct {
        bold: u1,
        half_bright: u1,
        italic: u1,
        underscore: u1,
        blink: u1,
        reverse_video: u1,
        underline: u1,
        normal_intensity: u1,
        off_italic: u1,
        off_underline: u1,
        off_blink: u1,
        off_reverse_video: u1,
    };
    storage: Storage,

    pub fn new() Self {
        return std.mem.zeroes(Self);
    }
    pub fn set(self: Self, style: SGR.Style, enable: bool) Self {
        var obj = self;
        inline for (std.meta.fields(Storage)) |field| {
            if (std.mem.eql(u8, field.name, @tagName(style))) {
                return obj.field_set(field.name, enable);
            }
        }
        unreachable;
    }

    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        var first = true;
        inline for (std.meta.fields(Storage)) |field| {
            if (self.field_get(field.name)) {
                if (!first) {
                    try writer.writeByte(parameter.sep);
                }
                try enumFormat_d(std.meta.stringToEnum(SGR.Style, field.name).?, writer);
                first = false;
            }
        }
    }

    fn field_set(self: Self, comptime name: LiteralString, enable: bool) Self {
        var obj = self;
        @field(obj.storage, name) = if (enable) 1 else 0;
        return obj;
    }
    fn field_get(self: Self, comptime name: LiteralString) bool {
        return 1 == @field(self.storage, name);
    }

    const _test = struct {
        const testing = std.testing;
        test Style {
            try testing.expectEqualStrings("", print("{}", .{comptime new()}));
            try testing.expectEqualStrings("1", print("{}", .{comptime new().set(.bold, true)}));
            try testing.expectEqualStrings(
                "1;21",
                print("{}", .{comptime new().set(.bold, true).set(.underline, true)}),
            );
            try testing.expectEqualStrings(
                "1;3;21",
                print("{}", .{comptime new()
                    .set(.bold, true)
                    .set(.underline, true)
                    .set(.italic, true)}),
            );
            try testing.expectEqualStrings(
                print("{}", .{comptime new().set(.bold, true).set(.italic, true)}),
                print("{}", .{comptime new().set(.bold, true).set(.underline, true).set(.italic, true).set(.underline, false)}),
            );
        }
    };
};

pub const Color = struct {
    const Self = @This();
    const Color8 = SGR.Color.Color8;
    const Color256 = SGR.Color.ColorX.Color256;
    const ColorRGB = SGR.Color.ColorX.ColorRGB;
    const Storage = union(enum) {
        default,
        color8: Color8,
        color256: Color256,
        colorRGB: ColorRGB,
    };
    /// bright versions of color8
    _bright: bool = false,
    background: bool = false,
    storage: Storage,

    /// set default color (before Linux 3.16: set underscore off, set default color)
    pub const default: Self = .{ .storage = .default };
    pub fn color8(color: Color8, bright: bool) Self {
        return .{ .storage = .{ .color8 = color }, ._bright = bright };
    }
    pub fn color256(c: u8) Self {
        return .{ .storage = .{ .color256 = .{ .c = c } } };
    }
    pub fn colorIBGR(c: Color256.IBGR) Self {
        return color256(@intFromEnum(c));
    }
    pub fn colorGrayscale(c: Color256.Grayscale) Self {
        return color256(@intFromEnum(c));
    }
    pub fn colorRGB(r: u8, g: u8, b: u8) Self {
        return .{ .storage = .{ .colorRGB = .{ .r = r, .g = g, .b = b } } };
    }
    pub fn fg(self: Self) Self {
        var obj = self;
        obj.background = false;
        return obj;
    }
    pub fn bg(self: Self) Self {
        var obj = self;
        obj.background = true;
        return obj;
    }

    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        switch (self.storage) {
            .default => {
                var v = Color8.base(false) + Color8.default;
                if (self.background) v += SGR.Color.offset;
                return intFormat_d(v, writer);
            },
            .color8 => |c| {
                var v = Color8.base(self._bright) + @intFromEnum(c);
                if (self.background) v += SGR.Color.offset;
                return intFormat_d(v, writer);
            },
            else => {
                var pre = SGR.Color.ColorX.pre;
                if (self.background) pre += SGR.Color.offset;
                try intFormat_d(pre, writer);
                try writer.writeByte(parameter.sep);
                switch (self.storage) {
                    inline .color256, .colorRGB => |c| {
                        return anyFormat(c, writer);
                    },
                    // .colorRGB => |c| {
                    //     return anyFormat(c, writer);
                    // },
                    else => unreachable,
                }
            },
        }
    }

    const _test = struct {
        const testing = std.testing;
        test Color {
            try testing.expectEqualStrings("39", print("{}", .{comptime default}));
            try testing.expectEqualStrings("49", print("{}", .{comptime default.bg()}));
            try testing.expectEqualStrings("34", print("{}", .{comptime color8(.blue, false)}));
            try testing.expectEqualStrings("94", print("{}", .{comptime color8(.blue, true)}));
            try testing.expectEqualStrings("44", print("{}", .{comptime color8(.blue, false).bg()}));
            try testing.expectEqualStrings("38;5;9", print("{}", .{comptime color256(9)}));
            try testing.expectEqualStrings("48;5;9", print("{}", .{comptime color256(9).bg()}));
            try testing.expectEqualStrings("38;2;1;2;3", print("{}", .{comptime colorRGB(1, 2, 3)}));
            try testing.expectEqualStrings("48;2;1;2;3", print("{}", .{comptime colorRGB(1, 2, 3).bg()}));
            try testing.expectEqual(color256(9), color256(9).fg());
            try testing.expectEqual(color256(9).bg(), color256(9).fg().bg());
            try testing.expectEqual(color256(13), colorIBGR(.fuchsia));
            try testing.expectEqual(color256(231), colorGrayscale(.grey100));
        }
    };
};

pub const Attribute = struct {
    const Self = @This();
    const Storage = struct {
        style: ?Style = null,
        color: ?Color = null,
        bgColor: ?Color = null,
    };
    _trust: bool = false,
    storage: Storage,

    pub fn new() Self {
        return .{ .storage = .{} };
    }
    /// dont reset all attributes to their defaults first
    pub fn trust(self: Self) Self {
        var obj = self;
        obj._trust = true;
        return obj;
    }
    pub const reset = new();

    fn field_set(self: Self, comptime name: LiteralString, v: @FieldType(Storage, name)) Self {
        var obj = self;
        @field(obj.storage, name) = v;
        return obj;
    }
    pub fn style(self: Self, v: Style) Self {
        return self.field_set(@src().fn_name, v);
    }
    pub fn color(self: Self, v: Color) Self {
        return self.field_set(@src().fn_name, v.fg());
    }
    pub fn bgColor(self: Self, v: Color) Self {
        return self.field_set(@src().fn_name, v.bg());
    }

    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        try anyFormat(control.ESCSequence.CSI, writer);
        var first = true;
        if (!self._trust) {
            try intFormat_d(SGR.reset, writer);
            first = false;
        }
        inline for (std.meta.fields(Storage)) |field| {
            if (@field(self.storage, field.name)) |v| {
                if (!first) {
                    try writer.writeByte(parameter.sep);
                }
                try anyFormat(v, writer);
                first = false;
            }
        }
        try anyFormat(control.CSISequenceFunction.SGR, writer);
    }

    fn field_style_set(self: Self, comptime name: LiteralString) Self {
        var obj = self;
        const _style = obj.storage.style orelse Style.new();
        obj.storage.style = _style.field_set(name, true);
        return obj;
    }
    pub fn bold(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn half_bright(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn italic(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn underscore(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn blink(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn reverse_video(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn underline(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn normal_intensity(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn off_italic(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn off_underline(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn off_blink(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }
    pub fn off_reverse_video(self: Self) Self {
        return self.field_style_set(@src().fn_name);
    }

    pub fn color8(self: Self, c: SGR.Color.Color8) Self {
        return self.color(Color.color8(c, false));
    }
    pub fn bgColor8(self: Self, c: SGR.Color.Color8) Self {
        return self.bgColor(Color.color8(c, false));
    }
    pub fn brightColor8(self: Self, c: SGR.Color.Color8) Self {
        return self.color(Color.color8(c, true));
    }
    pub fn bgBrightColor8(self: Self, c: SGR.Color.Color8) Self {
        return self.bgColor(Color.color8(c, true));
    }
    fn field_color8_set(self: Self, comptime name: LiteralString) Self {
        const c = std.meta.stringToEnum(SGR.Color.Color8, name).?;
        return self.color8(c);
    }
    pub fn black(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn red(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn green(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn brown(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn blue(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn magenta(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn cyan(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }
    pub fn white(self: Self) Self {
        return self.field_color8_set(@src().fn_name);
    }

    pub fn color256(self: Self, c: u8) Self {
        return self.color(Color.color256(c));
    }
    pub fn bgColor256(self: Self, c: u8) Self {
        return self.bgColor(Color.color256(c));
    }
    pub fn colorIBGR(self: Self, c: SGR.Color.ColorX.Color256.IBGR) Self {
        return self.color(Color.colorIBGR(c));
    }
    pub fn bgColorIBGR(self: Self, c: SGR.Color.ColorX.Color256.IBGR) Self {
        return self.bgColor(Color.colorIBGR(c));
    }
    pub fn colorGrayscale(self: Self, c: SGR.Color.ColorX.Color256.Grayscale) Self {
        return self.color(Color.colorGrayscale(c));
    }
    pub fn bgColorGrayscale(self: Self, c: SGR.Color.ColorX.Color256.Grayscale) Self {
        return self.bgColor(Color.colorGrayscale(c));
    }

    pub fn colorRGB(self: Self, r: u8, g: u8, b: u8) Self {
        return self.color(Color.colorRGB(r, g, b));
    }
    pub fn bgColorRGB(self: Self, r: u8, g: u8, b: u8) Self {
        return self.bgColor(Color.colorRGB(r, g, b));
    }

    const _test = struct {
        const testing = std.testing;
        test "Attribute raw APIs" {
            try testing.expectEqualStrings(
                "\x1b[0;1;34m",
                print("{}", .{comptime new()
                    .style(Style.new().set(.bold, true))
                    .color(Color.color8(.blue, false))}),
            );
            try testing.expectEqualStrings(
                "\x1b[1;3;39;107m",
                print("{}", .{comptime new().trust()
                    .style(Style.new().set(.bold, true).set(.italic, true))
                    .color(Color.default)
                    .bgColor(Color.color8(.white, true))}),
            );
            try testing.expectEqualStrings(
                "\x1b[1;38;2;1;2;3m",
                print("{}", .{comptime new().trust()
                    .style(Style.new().set(.bold, true))
                    .color(Color.colorRGB(1, 2, 3))}),
            );
        }
        test "Attribute style APIs" {
            try testing.expectEqualStrings(
                "\x1b[0;1;21m",
                print("{}", .{comptime new().bold().underline()}),
            );
        }
        test "Attribute color8 APIs" {
            try testing.expectEqual(new().color8(.blue), new().color(Color.color8(.blue, false)));
            try testing.expectEqual(new().bgColor8(.blue), new().bgColor(Color.color8(.blue, false)));
            try testing.expectEqual(new().brightColor8(.blue), new().color(Color.color8(.blue, true)));
            try testing.expectEqual(new().bgBrightColor8(.blue), new().bgColor(Color.color8(.blue, true)));
            try testing.expectEqual(new().blue(), new().color8(.blue));
            try testing.expectEqualStrings("\x1b[30m", print("{}", .{comptime new().black().trust()}));
            try testing.expectEqualStrings("\x1b[41m", print("{}", .{comptime new().bgColor8(.red).trust()}));
        }
        test "Attribute color256 APIs" {
            try testing.expectEqual(new().color256(1), new().color(Color.color256(1)));
            try testing.expectEqual(new().bgColor256(1), new().bgColor(Color.color256(1)));
            try testing.expectEqual(new().colorIBGR(.fuchsia), new().color(Color.colorIBGR(.fuchsia)));
            try testing.expectEqual(new().bgColorIBGR(.fuchsia), new().bgColor(Color.colorIBGR(.fuchsia)));
            try testing.expectEqual(new().colorGrayscale(.grey100), new().color(Color.colorGrayscale(.grey100)));
            try testing.expectEqual(new().bgColorGrayscale(.grey100), new().bgColor(Color.colorGrayscale(.grey100)));
        }
        test "Attribute colorRGB APIs" {
            try testing.expectEqual(new().colorRGB(1, 2, 3), new().color(Color.colorRGB(1, 2, 3)));
            try testing.expectEqual(new().bgColorRGB(1, 2, 3), new().bgColor(Color.colorRGB(1, 2, 3)));
            try testing.expectEqualStrings(
                "\x1b[38;2;1;2;3m",
                print("{}", .{comptime new().trust().colorRGB(1, 2, 3)}),
            );
        }
    };

    pub fn value(self: Self, v: anytype) Value(@TypeOf(v)) {
        return .new(self, v);
    }
    pub fn apply(self: Self, w: anytype) AttrWriter(@TypeOf(w)) {
        return .new(self, w);
    }
};

pub fn Value(T: type) type {
    return struct {
        attribute: Attribute,
        _keep: bool = false,
        value: T,

        const Self = @This();

        pub fn new(attr: Attribute, value: T) Self {
            return .{ .attribute = attr, .value = value };
        }
        pub fn keep(self: Self) Self {
            var obj = self;
            obj._keep = true;
            return obj;
        }

        pub fn format(self: Self, comptime fmt: []const u8, options: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
            try anyFormat(self.attribute, writer);
            try std.fmt.formatType(self.value, fmt, options, writer, std.fmt.default_max_depth);
            if (!self._keep) {
                try anyFormat(Attribute.reset, writer);
            }
        }
    };
}

pub fn AttrWriter(W: type) type {
    const PosiWriter = @import("cursor.zig").PosiWriter;

    return struct {
        attribute: Attribute,
        _keep: bool = false,
        inner: W,

        const Self = @This();

        pub fn new(attr: Attribute, writer: W) Self {
            return .{ .attribute = attr, .inner = writer };
        }
        pub fn keep(self: Self) Self {
            var obj = self;
            obj._keep = true;
            return obj;
        }

        pub fn print(self: Self, comptime fmt: []const u8, args: anytype) W.Error!void {
            try anyFormat(self.attribute, self.inner);
            try self.inner.print(fmt, args);
            if (!self._keep) {
                try anyFormat(Attribute.reset, self.inner);
            }
        }
        pub fn positioner(self: Self) PosiWriter(Self) {
            return .new(self);
        }
    };
}

const _test = struct {
    const testing = std.testing;
    const Preset = Attribute.new().trust().bold().green().bgColor8(.white).underline();
    test "Rich String" {
        try testing.expectEqualStrings(
            "\x1b[1;21;32;47mhello\x1b[0m",
            print("{s}", .{comptime Preset.value("hello")}),
        );
    }
    test "Rich int" {
        try testing.expectEqualStrings(
            "\x1b[1;21;32;47m00c1\x1b[0m",
            print("{x:04}", .{comptime Preset.value(0xc1)}),
        );
    }
    test "Rich bool" {
        try testing.expectEqualStrings(
            "\x1b[1;21;32;47mtrue",
            print("{}", .{comptime Preset.value(true).keep()}),
        );
    }
    test AttrWriter {
        var buffer = std.mem.zeroes([512]u8);
        var bufferStream = std.io.fixedBufferStream(&buffer);
        const writer = Preset.apply(bufferStream.writer());
        try writer.print("string {s} int {d}", .{ "hello", 6 });
        try testing.expectEqualStrings(
            "\x1b[1;21;32;47mstring hello int 6\x1b[0m",
            std.mem.sliceTo(&buffer, 0),
        );
    }
};

test {
    _ = Style._test;
    _ = Color._test;
    _ = Attribute._test;
    _ = _test;
}
