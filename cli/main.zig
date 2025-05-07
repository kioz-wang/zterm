const zargs = @import("zargs");
const Command = zargs.Command;
const Arg = zargs.Arg;

const app = Command.new("zterm_cli").requireSub("action")
    .version("0.0.1").author("Kioz Wang")
    .sub(@import("Color8.zig").cmd)
    .sub(@import("Here.zig").cmd);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const args = try app.parse(allocator);
    // var it = try zargs.TokenIter.initLine("gym", null, .{});
    // const args = try app.parseFrom(&it, allocator);
    defer app.destroy(&args, allocator);
}

const std = @import("std");
