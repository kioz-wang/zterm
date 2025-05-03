const std = @import("std");

const term = @import("Term").getStd();
const Attribute = @import("attr").Attribute;
const castVec2 = @import("cursor").castVec2;

const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const Self = @This();

const UNIT_FMT = " {s} ";

msg: []const u8,
unit_delay_ms: ?u64 = null,
line_delay_ms: ?u64 = null,
unit_width: u32,
unit_height: u32 = 2,
origin_row: u32 = 1,
origin_col: u32 = 1,
tbl_orow: u32 = undefined,
tbl_ocol: u32 = undefined,
hd_col_width: u32 = 6,
hd_row_height: u32 = 1,

fn new(msg: []const u8, row: u32, col: u32) Self {
    const width: u32 = @as(u32, @intCast(msg.len)) + 4;
    var self: Self = .{
        .msg = msg,
        .unit_width = width,
        .origin_row = row,
        .origin_col = col,
    };
    self.tbl_orow, self.tbl_ocol = .{ row + self.hd_row_height, col + self.hd_col_width };
    return self;
}
fn unit(self: Self, y: u32, x: u32, attr: Attribute) !void {
    if (self.unit_delay_ms) |ms| {
        std.time.sleep(std.time.ns_per_ms * ms);
    }
    const row = self.tbl_orow + y * self.unit_height;
    const col = self.tbl_ocol + x * self.unit_width;
    try term.attror(attr).posiPrint()
        .at(castVec2(col, row), Self.UNIT_FMT, .{self.msg});
    try term.attror(attr.bold()).posiPrint()
        .at(castVec2(col, row + 1), Self.UNIT_FMT, .{self.msg});
}
fn gYm(self: Self) !void {
    const cursor = term.cursor();

    try term.eraseDisplay(.whole);

    var row: u32 = 0;
    while (row <= 8) : (row += 1) {
        var attr = Attribute.new();
        if (row != 0) {
            attr = attr.color8(@enumFromInt(row - 1));
        }
        var col: u32 = 0;
        while (col <= 8) : (col += 1) {
            if (col != 0) {
                attr = attr.bgColor8(@enumFromInt(col - 1));
            }
            try self.unit(row, col, attr);
        }
        if (self.line_delay_ms) |ms| {
            std.time.sleep(std.time.ns_per_ms * ms);
        }
    }
    try term.attror(.reset).print("", .{});

    var col: u32 = 1;
    while (col <= 8) : (col += 1) {
        try term.posiPrint().at(
            castVec2(self.tbl_ocol + col * self.unit_width, self.origin_row),
            " 4{d}m ",
            .{col - 1},
        );
    }

    row = 0;
    while (row <= 8) : (row += 1) {
        var buffer: [16]u8 = undefined;
        var ptr: []const u8 = &buffer;
        var attr = Attribute.new().trust();
        if (row != 0) {
            attr = attr.color8(@enumFromInt(row - 1));
        }
        const _row: u32 = self.tbl_orow + row * self.unit_height;
        const _col: u32 = self.origin_col;
        ptr = try std.fmt.bufPrint(&buffer, "{}", .{attr});
        try term.posiPrint().at(
            castVec2(_col, _row),
            "{s:5} ",
            .{if (std.mem.startsWith(u8, ptr, "\x1b[")) ptr[2..] else ptr},
        );
        ptr = try std.fmt.bufPrint(&buffer, "{}", .{attr.bold()});
        try term.posiPrint().at(
            castVec2(_col, _row + 1),
            "{s:5} ",
            .{if (std.mem.startsWith(u8, ptr, "\x1b[")) ptr[2..] else ptr},
        );
    }

    try cursor.rowAt(self.tbl_orow + 8 * self.unit_height + 2);
    try cursor.downBegin(2);
}

const _cmd = Command.new("color-test").alias("gYm").alias("gym")
    .arg(Arg.posArg("msg", []const u8).default("gYm"))
    .arg(Arg.optArg("line_delay_ms", ?u64).short('D'))
    .arg(Arg.optArg("unit_delay_ms", ?u64).short('d'));
fn cb(args: *_cmd.Result()) void {
    var color_test = Self.new(args.msg, 2, 2);
    color_test.line_delay_ms = args.line_delay_ms;
    color_test.unit_delay_ms = args.unit_delay_ms;
    color_test.gYm() catch |e| zargs.exit(e, 1);
}

pub const cmd = Self._cmd.callBack(Self.cb);
