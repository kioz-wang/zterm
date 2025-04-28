const std = @import("std");

const terminel = @import("terminal.zig");
const attribute = @import("attr");

pub const Style = attribute.Style;
pub const Color = attribute.Color;
pub const Attribute = attribute.Attribute;

pub const apply = terminel.apply;

const FileWriter = std.fs.File.Writer;

pub fn stdout() terminel.TermWriter(FileWriter) {
    return apply(std.io.getStdOut().writer());
}
pub fn stderr() terminel.TermWriter(FileWriter) {
    return apply(std.io.getStdErr().writer());
}
