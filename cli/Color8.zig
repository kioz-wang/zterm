const std = @import("std");

const Term = @import("Term");
const term = Term.getStd();
const Attribute = Term.attr.Attribute;
const castVec2 = Term.cursor.castVec2;
const scaleVec2 = Term.cursor.scaleVec2;
const Vec2 = Term.cursor.Vec2;

const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const Self = @This();

const UNIT_FMT = " {s} ";
const HEADER = Vec2{ 7, 1 };

msg: []const u8,
unit_delay_ms: ?u64 = null,
line_delay_ms: ?u64 = null,
unit_sz: Vec2,
origin: Vec2,
tbl_origin: Vec2 = undefined,

fn new(msg: []const u8, _origin: Vec2) Self {
    var self: Self = .{
        .msg = msg,
        .unit_sz = castVec2(msg.len + 4, 2),
        .origin = _origin,
    };
    self.tbl_origin = self.origin + Self.HEADER;
    return self;
}
fn unit(self: Self, p: Vec2, attr: Attribute) !void {
    if (self.unit_delay_ms) |ms| {
        std.time.sleep(std.time.ns_per_ms * ms);
    }
    const point = self.tbl_origin + (scaleVec2(p, self.unit_sz) orelse unreachable);
    try term.mvaprint(.at(point), attr, Self.UNIT_FMT, .{self.msg});
    try term.mvaprint(.at(point + Vec2{ 0, 1 }), attr.bold(), Self.UNIT_FMT, .{self.msg});
}
fn gYm(self: Self) !void {
    const cursor = Term.cursor.cursor(term.w);

    try term.eraseDisplay(.whole);

    var row: i32 = 0;
    while (row <= 8) : (row += 1) {
        var attr = Attribute.new().strict();
        if (row != 0) {
            attr = attr.color8(@enumFromInt(row - 1));
        }
        var col: i32 = 0;
        while (col <= 8) : (col += 1) {
            if (col != 0) {
                attr = attr.bgColor8(@enumFromInt(col - 1));
            }
            try self.unit(.{ col, row }, attr);
        }
        if (self.line_delay_ms) |ms| {
            std.time.sleep(std.time.ns_per_ms * ms);
        }
    }
    try term.aprint(.default, "", .{});

    var col: i32 = 1;
    while (col <= 8) : (col += 1) {
        try term.mvprint(
            .at(castVec2(self.tbl_origin[0] + col * self.unit_sz[0], self.origin[1])),
            " 4{d}m ",
            .{col - 1},
        );
    }

    row = 0;
    while (row <= 8) : (row += 1) {
        var buffer: [16]u8 = undefined;
        var ptr: []const u8 = &buffer;
        var attr = Attribute.new();
        if (row != 0) {
            attr = attr.color8(@enumFromInt(row - 1));
        }
        const point = Vec2{
            self.origin[0],
            self.tbl_origin[1] + row * self.unit_sz[1],
        };
        ptr = try std.fmt.bufPrint(&buffer, "{}", .{attr});
        try term.mvprint(
            .at(point),
            "{s:5} ",
            .{if (std.mem.startsWith(u8, ptr, "\x1b[")) ptr[2..] else ptr},
        );
        ptr = try std.fmt.bufPrint(&buffer, "{}", .{attr.bold()});
        try term.mvprint(
            .at(point + Vec2{ 1, 0 }),
            "{s:5} ",
            .{if (std.mem.startsWith(u8, ptr, "\x1b[")) ptr[2..] else ptr},
        );
    }

    try cursor.row(.at(self.tbl_origin[1] + 8 * self.unit_sz[1] + 2));
    try cursor.beginRow(.down(2));
}

const _cmd = Command.new("color-test").alias("gYm").alias("gym")
    .arg(Arg.optArg("origin", Vec2).long("at").default(Term.cursor.origin))
    .arg(Arg.posArg("msg", []const u8).default("gYm"))
    .arg(Arg.optArg("line_delay_ms", ?u64).short('D'))
    .arg(Arg.optArg("unit_delay_ms", ?u64).short('d'));
fn cb(args: *_cmd.Result()) void {
    var color_test = Self.new(args.msg, args.origin);
    color_test.line_delay_ms = args.line_delay_ms;
    color_test.unit_delay_ms = args.unit_delay_ms;
    color_test.gYm() catch |e| zargs.exit(e, 1);
}

pub const cmd = Self._cmd.callBack(Self.cb);
