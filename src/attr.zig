const std = @import("std");
const helper = @import("helper");
const alias = helper.alias;
const formatter = helper.formatter;
const Flag = helper.env.Flag;
const Stringify = helper.Stringify;

const print = alias.print;
const String = alias.String;
const LiteralString = alias.LiteralString;
const FormatOptions = alias.FormatOptions;

const formatAny = formatter.any;
const formatInt = formatter.dInt;

const ctl = @import("mapping").ctl;
const sep = @import("mapping").par.sep;
const SGR = @import("mapping").par.SGR;
const Color8 = SGR.Color.Color8;
const Color256 = SGR.Color.ColorX.Color256;
const ColorRGB = SGR.Color.ColorX.ColorRGB;

pub fn forceNoColor(b: bool) void {
    Flag(.NO_COLOR).force(b);
}
pub fn forceNoStyle(b: bool) void {
    Flag(.NO_STYLE).force(b);
}

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
    flag_strict: bool = false,

    pub fn new() Self {
        return std.mem.zeroes(Self);
    }
    pub fn set(self: Self, style: SGR.Style) Self {
        return self.runtime_field_set(style, true);
    }
    pub fn unset(self: Self, style: SGR.Style) Self {
        return self.runtime_field_set(style, false);
    }
    /// reset to default first
    pub fn strict(self: Self) Self {
        var obj = self;
        obj.flag_strict = true;
        return obj;
    }
    pub const default = new();
    pub const none = default;

    pub fn fprint(self: Self, w: anytype, comptime fmt: []const u8, args: anytype) @TypeOf(w).Error!void {
        try self.stringifyEnv(w);
        try std.fmt.format(w, fmt, args);
    }
    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, w: anytype) @TypeOf(w).Error!void {
        try self.stringifyEnv(w);
    }
    pub fn stringify(self: Self, w: anytype) @TypeOf(w).Error!void {
        try self.stringifyCSI(w, true);
    }
    pub fn toString(self: Self) *const [helper.stringify(self).count():0]u8 {
        return helper.stringify(self).literal();
    }
    pub fn value(self: Self, v: anytype) Value(Self, @TypeOf(v)) {
        return .new(self, v);
    }

    const _test = struct {
        const testing = std.testing;
        test Style {
            try testing.expectEqualStrings("", comptime new().toString());
            try testing.expectEqualStrings("\x1b[1m", comptime new().set(.bold).toString());
            try testing.expectEqualStrings("\x1b[0;1m", comptime new().set(.bold).strict().toString());
            try testing.expectEqualStrings(
                "\x1b[1;21m",
                comptime new().set(.bold).set(.underline).toString(),
            );
            try testing.expectEqualStrings(
                "\x1b[0;1;21m",
                comptime new().strict().set(.bold).set(.underline).toString(),
            );
            try testing.expectEqualStrings(
                "\x1b[1;3;21m",
                comptime new().set(.bold).set(.underline).set(.italic).toString(),
            );
            try testing.expectEqualStrings(
                comptime new().set(.bold).set(.italic).toString(),
                comptime new().set(.bold).set(.underline).set(.italic).unset(.underline).toString(),
            );
        }
        test "Style Value" {
            const sprint = alias.sprint;
            var buffer: [32]u8 = undefined;
            forceNoStyle(false);
            try testing.expectEqualStrings(
                "\x1b[0;1mhello\x1b[0m",
                try sprint(&buffer, "{s}", .{new().set(.bold).value("hello")}),
            );
            try testing.expectEqualStrings(
                "\x1b[0;1mcc\x1b[0m",
                try sprint(&buffer, "{x}", .{new().set(.bold).value(@as(u16, 0xcc))}),
            );
        }
    };

    fn field_set(self: Self, comptime name: LiteralString, enable: bool) Self {
        var obj = self;
        @field(obj.storage, name) = if (enable) 1 else 0;
        return obj;
    }
    fn field_get(self: Self, comptime name: LiteralString) bool {
        return 1 == @field(self.storage, name);
    }
    fn runtime_field_set(self: Self, style: SGR.Style, enable: bool) Self {
        inline for (std.meta.fields(Storage)) |field| {
            if (std.mem.eql(u8, field.name, @tagName(style))) {
                return self.field_set(field.name, enable);
            }
        }
        unreachable;
    }

    fn stringifyCSI(self: Self, w: anytype, csi: bool) @TypeOf(w).Error!void {
        var first = true;
        if (self.flag_strict) {
            if (csi) try formatAny(ctl.ESCSequence.CSI, w);
            try formatInt(SGR.reset, w);
            first = false;
        }
        inline for (std.meta.fields(Storage)) |field| {
            if (self.field_get(field.name)) {
                if (csi and first) try formatAny(ctl.ESCSequence.CSI, w);
                if (!first) try w.writeByte(sep);
                try formatter.dEnum(std.meta.stringToEnum(SGR.Style, field.name).?, w);
                first = false;
            }
        }
        if (csi and !first) try formatAny(ctl.CSISequenceFunction.SGR, w);
    }
    fn stringifyEnv(self: Self, w: anytype) @TypeOf(w).Error!void {
        if (Flag(.NO_STYLE).check()) return;
        try self.stringify(w);
    }
};

pub const Color = struct {
    const Self = @This();
    const Storage = union(enum) {
        default,
        color8: Color8,
        color256: Color256,
        colorRGB: ColorRGB,
    };
    storage: Storage,
    /// bright versions of color8
    flag_bright: bool = false,
    flag_bg: bool = false,
    flag_strict: bool = false,

    pub fn color8(color: Color8, bright: bool) Self {
        return .{ .storage = .{ .color8 = color }, .flag_bright = bright };
    }
    pub fn color256(c: u8) Self {
        return .{ .storage = .{ .color256 = .{ .c = c } } };
    }
    pub fn colorRGB(r: u8, g: u8, b: u8) Self {
        return .{ .storage = .{ .colorRGB = .{ .r = r, .g = g, .b = b } } };
    }
    pub fn fg(self: Self) Self {
        var obj = self;
        obj.flag_bg = false;
        return obj;
    }
    pub fn bg(self: Self) Self {
        var obj = self;
        obj.flag_bg = true;
        return obj;
    }
    /// reset to default first
    pub fn strict(self: Self) Self {
        var obj = self;
        obj.flag_strict = true;
        return obj;
    }
    /// set default color (before Linux 3.16: set underscore off, set default color)
    pub const default: Self = .{ .storage = .default };

    pub fn colorIBGR(c: Color256.IBGR) Self {
        return color256(@intFromEnum(c));
    }
    pub fn colorGrayscale(c: Color256.Grayscale) Self {
        return color256(@intFromEnum(c));
    }
    pub fn colorHex(c: u24) Self {
        const endian = @import("builtin").target.cpu.arch.endian();
        const rgb: [*]const u8 = @ptrCast(&c);
        return colorRGB(
            rgb[if (endian == .little) 2 else 0],
            rgb[1],
            rgb[if (endian == .little) 0 else 2],
        );
    }
    pub fn colorHexS(s: String) std.fmt.ParseIntError!Self {
        const raw_s = if (std.ascii.startsWithIgnoreCase(s, "0x")) s[2..] else if (s[0] == '#') s[1..] else s;
        const c = try std.fmt.parseInt(u24, raw_s, 16);
        return colorHex(c);
    }

    pub fn fprint(self: Self, w: anytype, comptime fmt: []const u8, args: anytype) @TypeOf(w).Error!void {
        try self.stringifyEnv(w);
        try std.fmt.format(w, fmt, args);
    }
    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, w: anytype) @TypeOf(w).Error!void {
        try self.stringifyEnv(w);
    }
    pub fn stringify(self: Self, w: anytype) @TypeOf(w).Error!void {
        try self.stringifyCSI(w, true);
    }
    pub fn toString(self: Self) *const [helper.stringify(self).count():0]u8 {
        return helper.stringify(self).literal();
    }
    pub fn value(self: Self, v: anytype) Value(Self, @TypeOf(v)) {
        return .new(self, v);
    }

    const _test = struct {
        const testing = std.testing;
        test Color {
            try testing.expectEqualStrings("\x1b[39m", comptime default.toString());
            try testing.expectEqualStrings("\x1b[0;39m", comptime default.strict().toString());
            try testing.expectEqualStrings("\x1b[49m", comptime default.bg().toString());
            try testing.expectEqualStrings("\x1b[34m", comptime color8(.blue, false).toString());
            try testing.expectEqualStrings("\x1b[94m", comptime color8(.blue, true).toString());
            try testing.expectEqualStrings("\x1b[44m", comptime color8(.blue, false).bg().toString());
            try testing.expectEqualStrings("\x1b[38;5;9m", comptime color256(9).toString());
            try testing.expectEqualStrings("\x1b[48;5;9m", comptime color256(9).bg().toString());
            try testing.expectEqualStrings("\x1b[0;48;5;9m", comptime color256(9).bg().strict().toString());
            try testing.expectEqualStrings("\x1b[38;2;1;2;3m", comptime colorRGB(1, 2, 3).toString());
            try testing.expectEqualStrings("\x1b[48;2;1;2;3m", comptime colorRGB(1, 2, 3).bg().toString());
            try testing.expectEqual(color256(9), color256(9).fg());
            try testing.expectEqual(color256(9).bg(), color256(9).fg().bg());
            try testing.expectEqual(color256(13), colorIBGR(.fuchsia));
            try testing.expectEqual(color256(231), colorGrayscale(.grey100));
            try testing.expectEqual(colorRGB(1, 2, 3), colorHex(0x010203));
            try testing.expectEqual(colorRGB(1, 2, 3), colorHexS("#010203"));
            try testing.expectEqual(colorRGB(1, 2, 3), colorHexS("010203"));
            try testing.expectEqual(colorRGB(1, 2, 3), colorHexS("0x010203"));
            try testing.expectEqual(colorRGB(1, 2, 3), colorHexS("0x10203"));
            try testing.expectEqual(colorRGB(1, 2, 3), comptime colorHexS("0x10203"));
        }
        test "Color Value" {
            const sprint = alias.sprint;
            var buffer: [32]u8 = undefined;
            forceNoColor(false);
            try testing.expectEqualStrings(
                "\x1b[0;38;2;1;2;3mhello\x1b[0m",
                try sprint(
                    &buffer,
                    "{s}",
                    .{(colorHexS("#010203") catch unreachable).value("hello")},
                ),
            );
            try testing.expectEqualStrings(
                "\x1b[0;94mcc\x1b[0m",
                try sprint(&buffer, "{x}", .{color8(.blue, true).value(@as(u16, 0xcc))}),
            );
        }
    };

    fn stringifyCSI(self: Self, w: anytype, csi: bool) @TypeOf(w).Error!void {
        if (csi) try formatAny(ctl.ESCSequence.CSI, w);
        if (self.flag_strict) {
            try formatInt(SGR.reset, w);
            try w.writeByte(sep);
        }
        switch (self.storage) {
            .default => {
                var v = Color8.base(false) + Color8.default;
                if (self.flag_bg) v += SGR.Color.offset;
                try formatInt(v, w);
            },
            .color8 => |c| {
                var v = Color8.base(self.flag_bright) + @intFromEnum(c);
                if (self.flag_bg) v += SGR.Color.offset;
                try formatInt(v, w);
            },
            inline .color256, .colorRGB => |c| {
                var pre = SGR.Color.ColorX.pre;
                if (self.flag_bg) pre += SGR.Color.offset;
                try formatInt(pre, w);
                try w.writeByte(sep);
                try formatAny(c, w);
            },
        }
        if (csi) try formatAny(ctl.CSISequenceFunction.SGR, w);
    }
    fn stringifyEnv(self: Self, w: anytype) @TypeOf(w).Error!void {
        if (Flag(.NO_COLOR).check()) return;
        try self.stringify(w);
    }
};

pub const Attribute = struct {
    const Self = @This();
    const Storage = struct {
        style: ?Style = null,
        color: ?Color = null,
        bgColor: ?Color = null,
    };
    storage: Storage,
    flag_strict: bool = false,

    pub fn new() Self {
        return .{ .storage = .{} };
    }
    /// reset to default first
    pub fn strict(self: Self) Self {
        var obj = self;
        obj.flag_strict = true;
        return obj;
    }
    pub const default = Self{ .storage = .{
        .style = .default,
        .color = Color.default.fg(),
        .bgColor = Color.default.bg(),
    } };
    pub const none = new();
    pub const reset = new().strict();

    pub fn style(self: Self, v: Style) Self {
        return if (v.storage != Style.new().storage)
            self.field_set(@src().fn_name, v)
        else
            self;
    }
    pub fn color(self: Self, v: Color) Self {
        return self.field_set(@src().fn_name, v.fg());
    }
    pub fn bgColor(self: Self, v: Color) Self {
        return self.field_set(@src().fn_name, v.bg());
    }

    pub fn fprint(self: Self, w: anytype, comptime fmt: []const u8, args: anytype) @TypeOf(w).Error!void {
        try self.stringifyEnv(w);
        try std.fmt.format(w, fmt, args);
    }
    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, w: anytype) @TypeOf(w).Error!void {
        try self.stringifyEnv(w);
    }
    pub fn stringify(self: Self, w: anytype) @TypeOf(w).Error!void {
        try self.stringifyCSI(w, true);
    }
    pub fn toString(self: Self) *const [helper.stringify(self).count():0]u8 {
        return helper.stringify(self).literal();
    }
    pub fn value(self: Self, v: anytype) Value(Self, @TypeOf(v)) {
        return .new(self, v);
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
                comptime new().strict().style(Style.new().set(.bold))
                    .color(Color.color8(.blue, false)).toString(),
            );
            try testing.expectEqualStrings(
                "\x1b[0;34m",
                comptime new().strict().style(Style.new())
                    .color(Color.color8(.blue, false)).toString(),
            );
            try testing.expectEqualStrings(
                "\x1b[1;3;39;107m",
                comptime new()
                    .style(Style.new().set(.bold).set(.italic))
                    .color(Color.default)
                    .bgColor(Color.color8(.white, true)).toString(),
            );
            try testing.expectEqualStrings(
                "\x1b[1;38;2;1;2;3m",
                comptime new().style(Style.new().set(.bold))
                    .color(Color.colorRGB(1, 2, 3)).toString(),
            );
        }
        test "Attribute style APIs" {
            try testing.expectEqualStrings(
                "\x1b[0;1;21m",
                comptime new().strict().bold().underline().toString(),
            );
        }
        test "Attribute color8 APIs" {
            try testing.expectEqual(new().color8(.blue), new().color(Color.color8(.blue, false)));
            try testing.expectEqual(new().bgColor8(.blue), new().bgColor(Color.color8(.blue, false)));
            try testing.expectEqual(new().brightColor8(.blue), new().color(Color.color8(.blue, true)));
            try testing.expectEqual(new().bgBrightColor8(.blue), new().bgColor(Color.color8(.blue, true)));
            try testing.expectEqual(new().blue(), new().color8(.blue));
            try testing.expectEqualStrings("\x1b[30m", comptime new().black().toString());
            try testing.expectEqualStrings("\x1b[41m", comptime new().bgColor8(.red).toString());
        }
        test "Attribute color256 APIs" {
            try testing.expectEqual(new().color256(1), new().color(Color.color256(1)));
            try testing.expectEqual(new().bgColor256(1), new().bgColor(Color.color256(1)));
        }
        test "Attribute colorRGB APIs" {
            try testing.expectEqual(new().colorRGB(1, 2, 3), new().color(Color.colorRGB(1, 2, 3)));
            try testing.expectEqual(new().bgColorRGB(1, 2, 3), new().bgColor(Color.colorRGB(1, 2, 3)));
            try testing.expectEqualStrings("\x1b[38;2;1;2;3m", comptime new().colorRGB(1, 2, 3).toString());
            {
                const sprint = alias.sprint;
                var buffer0: [32]u8 = undefined;
                var buffer1: [32]u8 = undefined;
                forceNoColor(false);
                forceNoStyle(true);
                try testing.expectEqualStrings(
                    try sprint(&buffer0, "{}", .{new().colorRGB(1, 2, 3).bold()}),
                    try sprint(&buffer1, "{}", .{new().colorRGB(1, 2, 3).italic()}),
                );
            }
        }
        test "Attribute Value" {
            const sprint = alias.sprint;
            const attr = Attribute.new().bold().green().bgColor8(.white).underline();
            var buffer: [32]u8 = undefined;
            forceNoColor(false);
            forceNoStyle(false);
            try testing.expectEqualStrings(
                "\x1b[0;1;21;32;47mhello\x1b[0m",
                try sprint(&buffer, "{s}", .{attr.value("hello")}),
            );
            try testing.expectEqualStrings(
                "\x1b[0;1;21;32;47m00c1\x1b[0m",
                try sprint(&buffer, "{x:04}", .{attr.value(@as(u32, 0xc1))}),
            );
            try testing.expectEqualStrings(
                "\x1b[0;1;21;32;47mtrue\x1b[0m",
                try sprint(&buffer, "{}", .{attr.value(true)}),
            );
        }
        test "Attribute Writer" {
            const attr = Attribute.new().bold().green().bgColor8(.white).underline();
            var buffer = std.mem.zeroes([512]u8);
            forceNoColor(false);
            forceNoStyle(false);
            var bs = std.io.fixedBufferStream(&buffer);
            try attr.fprint(bs.writer(), "string {s} int {d}", .{ "hello", 6 });
            try testing.expectEqualStrings(
                "\x1b[1;21;32;47mstring hello int 6",
                std.mem.sliceTo(&buffer, 0),
            );
        }
    };

    fn field_set(self: Self, comptime name: LiteralString, v: @FieldType(Storage, name)) Self {
        var obj = self;
        @field(obj.storage, name) = v;
        return obj;
    }
    fn field_style_set(self: Self, comptime name: LiteralString) Self {
        var obj = self;
        const _style = obj.storage.style orelse Style.new();
        obj.storage.style = _style.field_set(name, true);
        return obj;
    }
    fn field_color8_set(self: Self, comptime name: LiteralString) Self {
        const c = std.meta.stringToEnum(SGR.Color.Color8, name).?;
        return self.color8(c);
    }

    fn stringifyCSI(self: Self, w: anytype, csi: bool) @TypeOf(w).Error!void {
        var first = true;
        if (self.flag_strict) {
            if (csi) try formatAny(ctl.ESCSequence.CSI, w);
            try formatInt(SGR.reset, w);
            first = false;
        }
        inline for (std.meta.fields(Storage)) |field| {
            if (@field(self.storage, field.name)) |v| {
                if (csi and first) try formatAny(ctl.ESCSequence.CSI, w);
                if (!first) try w.writeByte(sep);
                var relaxed = v;
                relaxed.flag_strict = false;
                try relaxed.stringifyCSI(w, false);
                first = false;
            }
        }
        if (csi and !first) try formatAny(ctl.CSISequenceFunction.SGR, w);
    }
    fn stringifyEnv(self: Self, w: anytype) @TypeOf(w).Error!void {
        if (Flag(.NO_COLOR).check() and Flag(.NO_STYLE).check())
            return;
        var obj = self;
        if (Flag(.NO_COLOR).check()) {
            obj.storage.color = null;
            obj.storage.bgColor = null;
        }
        if (Flag(.NO_STYLE).check()) {
            obj.storage.style = null;
        }
        try obj.stringify(w);
    }
};

pub fn Value(A: type, V: type) type {
    return struct {
        a: A,
        v: V,
        const Self = @This();

        pub fn new(attr: A, value: V) Self {
            return .{ .a = attr.strict(), .v = value };
        }

        pub fn format(self: Self, comptime fmt: []const u8, options: FormatOptions, w: anytype) @TypeOf(w).Error!void {
            try self.a.stringifyEnv(w);
            try std.fmt.formatType(self.v, fmt, options, w, std.fmt.default_max_depth);
            try Attribute.reset.stringifyEnv(w);
        }
    };
}

test {
    _ = Style._test;
    _ = Color._test;
    _ = Attribute._test;
}
