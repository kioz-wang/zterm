const std = @import("std");
const assert = std.debug.assert;
const helper = @import("helper.zig");
const print = helper.Alias.print;
const FormatOptions = helper.Alias.FormatOptions;
const intFormat_d = helper.Formatter.intFormat_d;

pub const sep: u8 = ';';

/// The ECMA-48 SGR sequence `ESC [` parameters m sets display attributes. Several attributes can be set in the same sequence, separated by semicolons. An empty parameter (between semicolons or string initiator or terminator) is interpreted as a zero.
pub const SGR = struct {
    pub const reset: u8 = 0;

    pub const Style = enum(u8) {
        bold = 1,
        half_bright,
        italic,
        underscore,
        blink,
        reverse_video = 7,
        underline = 21,
        normal_intensity,
        off_italic,
        off_underline,
        off_blink,
        off_reverse_video = 27,
    };

    pub const Color = struct {
        pub const offset: u8 = 10;

        pub const Color8 = enum(u8) {
            pub fn base(bright: bool) u8 {
                return if (bright) 90 else 30;
            }
            pub const default: u8 = 9;
            black = 0,
            red,
            green,
            brown,
            blue,
            magenta,
            cyan,
            white,
        };

        pub const ColorX = struct {
            pub const pre: u8 = 38;

            pub const Color256 = struct {
                const Self = @This();
                const pre: u8 = 5;
                pub const IBGR = enum(u8) {
                    black = 0,
                    maroon,
                    green,
                    olive,
                    navy,
                    purple,
                    teal,
                    silver,
                    grey,
                    red,
                    lime,
                    yellow,
                    blue,
                    fuchsia,
                    aqua,
                    white,
                };
                pub const Grayscale = enum(u8) {
                    grey100 = 231,
                    grey3,
                    grey7,
                    grey11,
                    grey15,
                    grey19,
                    grey23,
                    grey27,
                    grey30,
                    grey35,
                    grey39,
                    grey42,
                    grey46,
                    grey50,
                    grey54,
                    grey58,
                    grey62,
                    grey66,
                    grey70,
                    grey74,
                    grey78,
                    grey82,
                    grey85,
                    grey89,
                    grey93,
                };

                c: u8,

                pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
                    try intFormat_d(Self.pre, writer);
                    try writer.writeByte(sep);
                    return intFormat_d(self.c, writer);
                }

                const _test = struct {
                    const testing = std.testing;
                    test Color256 {
                        try testing.expectEqualStrings("5;66", print("{}", .{Self{ .c = 66 }}));
                        try testing.expectEqualStrings("5;12", print("{}", .{Self{ .c = @intFromEnum(IBGR.blue) }}));
                        try testing.expectEqualStrings("5;241", print("{}", .{Self{ .c = @intFromEnum(Grayscale.grey39) }}));
                    }
                };
            };

            pub const ColorRGB = packed struct {
                const Self = @This();
                const pre: u8 = 2;

                r: u8,
                g: u8,
                b: u8,

                pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
                    try intFormat_d(Self.pre, writer);
                    try writer.writeByte(sep);
                    try intFormat_d(self.r, writer);
                    try writer.writeByte(sep);
                    try intFormat_d(self.g, writer);
                    try writer.writeByte(sep);
                    return intFormat_d(self.b, writer);
                }

                const _test = struct {
                    const testing = std.testing;
                    test ColorRGB {
                        try testing.expectEqualStrings("2;1;2;3", print("{}", .{Self{ .r = 1, .g = 2, .b = 3 }}));
                    }
                };
            };
        };
    };
};

/// Erase display (default: from cursor to end of display)
pub const ED = enum(u8) {
    /// erase from start to cursor
    backward = 1,
    /// erase whole display
    whole,
    /// erase whole display including scroll-back buffer (since Linux 3.0)
    whole_scroll,
};

/// Erase line (default: from cursor to end of line)
pub const EL = enum(u8) {
    /// erase from start of line to cursor
    backward = 1,
    /// erase whole line
    whole,
};

/// Set keyboard LEDs
pub const DECLL = enum(u8) {
    /// clear all LEDs
    clearall = 0,
    /// set Scroll Lock LED
    setScroll,
    /// set Num Lock LED
    setNum,
    /// set Caps Lock LED
    setCaps,
};

/// ECMA-48 Mode Switches
pub const SM = enum(u8) {
    /// DECCRM (default off): Display control chars
    DECCRM = 3,
    /// DECIM (default off): Set insert mode
    DECIM,
    /// LF/NL (default off): Automatically follow echo of LF, VT, or FF with CR
    LF_NL = 20,
};

/// DEC Private Mode (DECSET/DECRST) sequences
///
/// These are not described in ECMA-48. We list the Set Mode sequences; the Reset Mode sequences are obtained by replacing the final 'h' by 'l'.
pub const DECPM = enum(u8) {
    const pre: u8 = '?';

    /// DECCKM (default off): When set, the cursor keys send an `ESC O` prefix, rather than `ESC [`.
    DECCKM = 1,
    /// DECCOLM (default off = 80 columns): 80/132 col mode switch. The driver sources note that this alone does not suffice; some user-mode utility such as resizecons (8) has to change the hardware registers on the console video card.
    DECCOLM = 3,
    /// DECSCNM (default off): Set reverse-video mode.
    DECSCNM = 5,
    /// DECOM (default  off): When set, cursor addressing is relative to the upper left corner of the scrolling region.
    DECOM,
    /// DECAWM (default on): Set autowrap on. In this mode, a graphic character emitted after column 80 (or column 132 of DECCOLM is on) forces a wrap to the beginning of the following line first.
    DECAWM,
    /// DECARM (default on): Set keyboard autorepeat on.
    DECARM,
    // X10 Mouse Reporting (default off): Set reporting mode to 1 (or reset to 0)—see below.
    // = 9,
    /// DECTECM (default on): Make cursor visible.
    DECTECM = 25,
    // X11 Mouse Reporting (default off): Set reporting mode to 2 (or reset to 0)—see below.
    // = 1000,
};

/// ECMA-48 Status Report Commands
pub const DSR = enum(u8) {
    /// Device status report (DSR): Answer is `ESC [ 0 n` (Terminal OK)
    DSR = 5,
    /// Cursor position report (CPR): Answer is `ESC [ y ; x R`, where `x,y` is the cursor location
    CPR,
};

test {
    _ = SGR.Color.ColorX.Color256._test;
    _ = SGR.Color.ColorX.ColorRGB._test;
}
