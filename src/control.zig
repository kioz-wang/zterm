const std = @import("std");
const helper = @import("helper.zig");
const print = helper.Alias.print;
const FormatOptions = helper.Alias.FormatOptions;
const anyFormat = helper.Formatter.anyFormat;
const enumFormat_c = helper.Formatter.enumFormat_c;

pub const ControlCharater = enum(u8) {
    const Self = @This();

    /// beeps
    BEL = 0x07,
    /// backspaces one column (but not past the beginning of the line)
    BS,
    /// goes to the next tab stop or to the end of the line if there is no earlier tab stop
    HT,
    /// all give a linefeed, and if LF/NL (new-line mode) is set also a carriage return
    LF,
    /// see `LF`
    VT,
    /// see `LF`
    FF,
    /// gives a carriage return
    CR,
    /// activates the G1 character set
    SO,
    /// activates the G0 character set
    SI,
    /// abort any escape sequences
    CAN = 0x18,
    /// see `CAN`
    SUB = 0x1A,
    /// starts an escape sequence, possibly aborting a previous unfinished one
    ESC,
    /// is ignored
    DEL = 0x7F,
    /// is equivalent to `ESC [`
    CSI = 0x9B,

    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        return writer.writeByte(@intFromEnum(self));
    }

    const _test = struct {
        const testing = std.testing;
        test ControlCharater {
            try testing.expectEqual(0x0F, @intFromEnum(ControlCharater.SI));
            try testing.expectEqual(0x1B, @intFromEnum(ControlCharater.ESC));
            try testing.expectEqualStrings("\x1b", print("{}", .{Self.ESC}));
            try testing.expectEqualStrings("\x9b", print("{}", .{Self.CSI}));
        }
    };
};

pub const ESCSequence = enum(u8) {
    /// Reset
    RIS = 'c',
    /// Linefeed
    IND = 'D',
    /// Newline
    NEL = 'E',
    /// Set tab stop at current column
    HTS = 'H',
    /// Reverse linefeed
    RI = 'M',
    /// DEC private identification. The kernel returns the string  ESC [ ? 6 c, claiming that it is a VT102
    DECID = 'Z',
    /// Save current state (cursor coordinates, attributes, character sets pointed at by G0, G1)
    DECSC = '7',
    /// Restore state most recently saved by ESC 7
    DECRC = '8',
    /// Set numeric keypad mode
    DECPNM = '>',
    /// Set application keypad mode
    DECPAM = '=',
    /// Operating System Command prefix
    OSC = ']',
    /// Control Sequence Introducer
    CSI = '[',

    pub fn format(self: ESCSequence, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        try anyFormat(ControlCharater.ESC, writer);
        return enumFormat_c(self, writer);
    }

    /// `%` Start sequence selecting character set
    pub const SelectCharSet = enum(u8) {
        const Self = @This();
        const pre: u8 = '%';

        /// Select default (ISO/IEC 646 / ISO/IEC 8859-1)
        Default = '@',
        /// Select UTF-8
        UTF8 = 'G',
        /// Select UTF-8 (obsolete)
        UTF8_Obsolete = '8',

        pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
            return format_with_pre(self, Self.pre, writer);
        }
    };
    /// `#`
    pub const ScreenAlignTest = enum(u8) {
        const Self = @This();
        const pre: u8 = '#';

        /// DEC screen alignment test - fill screen with E's
        DECALN = '8',

        pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
            return format_with_pre(self, Self.pre, writer);
        }
    };
    /// `(` Start sequence defining G0 character set
    pub const DefG0CharSet = DefGxCharSet(true);
    /// `)` Start sequence defining G1 character set
    pub const DefG1CharSet = DefGxCharSet(false);
    /// `]`
    pub const Palette = enum(u8) {
        const Self = @This();
        const pre: u8 = ']';

        /// Reset palette
        Reset = 'R',
        /// Set palette, with parameter given in 7 hexadecimal digits nrrggbb after the final P. Here n is the color (0–15), and rrggbb indicates the red/green/blue values (0–255)
        Set = 'P',

        pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
            return format_with_pre(self, Self.pre, writer);
        }
    };

    fn DefGxCharSet(G0: bool) type {
        return enum(u8) {
            const Self = @This();
            const pre: u8 = if (G0) '(' else ')';

            /// Select default (ISO/IEC 8859-1 mapping)
            Default = 'B',
            /// Select VT100 graphics mapping
            VT100 = '0',
            /// Select null mapping - straight to character ROM
            Null = 'U',
            /// Select user mapping - the map that is loaded by the utility mapscrn(8)
            User = 'K',

            pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
                return format_with_pre(self, Self.pre, writer);
            }
        };
    }
    fn format_with_pre(v: anytype, pre: u8, writer: anytype) @TypeOf(writer).Error!void {
        try anyFormat(ControlCharater.ESC, writer);
        try writer.writeByte(pre);
        return enumFormat_c(v, writer);
    }

    const _test = struct {
        const testing = std.testing;
        test ESCSequence {
            try testing.expectEqual(']', @intFromEnum(ESCSequence.OSC));
            try testing.expectEqualStrings("\x1b]", print("{}", .{ESCSequence.OSC}));
            try testing.expectEqualStrings("\x1b[", print("{}", .{ESCSequence.CSI}));
        }
        test SelectCharSet {
            try testing.expectEqual('@', @intFromEnum(SelectCharSet.Default));
            try testing.expectEqualStrings("\x1b%@", print("{}", .{SelectCharSet.Default}));
        }
        test ScreenAlignTest {
            try testing.expectEqual('8', @intFromEnum(ScreenAlignTest.DECALN));
            try testing.expectEqualStrings("\x1b#8", print("{}", .{ScreenAlignTest.DECALN}));
        }
        test DefGxCharSet {
            try testing.expectEqual('B', @intFromEnum(DefG0CharSet.Default));
            try testing.expectEqualStrings("\x1b(B", print("{}", .{DefG0CharSet.Default}));
            try testing.expectEqual('B', @intFromEnum(DefG1CharSet.Default));
            try testing.expectEqualStrings("\x1b)B", print("{}", .{DefG1CharSet.Default}));
        }
        test Palette {
            try testing.expectEqual('R', @intFromEnum(Palette.Reset));
            try testing.expectEqualStrings("\x1b]R", print("{}", .{Palette.Reset}));
        }
    };
};

/// The action of a CSI sequence is determined by its final character.
pub const CSISequenceFunction = enum(u8) {
    const Self = @This();

    /// Insert the indicated # of blank characters
    ICH = '@',
    /// Move cursor up the indicated # of rows
    CUU = 'A',
    /// Move cursor down the indicated # of rows
    CUD = 'B',
    /// Move cursor right the indicated # of columns
    CUF = 'C',
    /// Move cursor left the indicated # of columns
    CUB = 'D',
    /// Move cursor down the indicated # of rows, to column 1
    CNL = 'E',
    /// Move cursor up the indicated # of rows, to column 1
    CPL = 'F',
    /// Move cursor to indicated column in current row
    CHA = 'G',
    /// Move cursor to the indicated row, column (origin at `1,1`)
    CUP = 'H',
    /// Erase display (default: from cursor to end of display)
    ED = 'J',
    /// Erase line (default: from cursor to end of line)
    EL = 'K',
    /// Insert the indicated # of blank lines
    IL = 'L',
    /// Delete the indicated # of lines
    DL = 'M',
    /// Delete the indicated # of characters on current line
    DCH = 'P',
    /// Erase the indicated # of characters on current line
    ECH = 'X',
    /// Move cursor right the indicated # of columns
    HPR = 'a',
    /// Answer `ESC [ ? 6 c`: "I am a VT102"
    DA = 'c',
    /// Move cursor to the indicated row, current column
    VPA = 'd',
    /// Move cursor down the indicated # of rows
    VPR = 'e',
    /// Move cursor to the indicated row, column
    HVP = 'f',
    /// Without parameter: clear tab stop at current position
    TBC = 'g',
    /// Set Mode
    SM = 'h',
    /// Reset Mode
    RM = 'l',
    /// Set attributes
    SGR = 'm',
    /// Status report
    DSR = 'n',
    /// Set keyboard LEDs
    DECLL = 'q',
    /// Set scrolling region; parameters are top and bottom row
    DECSTBM = 'r',
    /// Save cursor location
    CUS = 's',
    /// Restore cursor location
    CUR = 'u',
    /// Move cursor to indicated column in current row
    HPA = '`',

    pub fn format(self: Self, comptime _: []const u8, _: FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        return enumFormat_c(self, writer);
    }
    pub fn param(self: Self, writer: anytype, comptime fmt: []const u8, args: anytype) @TypeOf(writer).Error!void {
        try anyFormat(ESCSequence.CSI, writer);
        try writer.print(fmt, args);
        try anyFormat(self, writer);
    }

    const _test = struct {
        const testing = std.testing;
        test CSISequenceFunction {
            try testing.expectEqual('m', @intFromEnum(Self.SGR));
            try testing.expectEqualStrings("m", print("{}", .{Self.SGR}));
        }
    };
};

test {
    _ = ControlCharater._test;
    _ = ESCSequence._test;
    _ = CSISequenceFunction._test;
}
