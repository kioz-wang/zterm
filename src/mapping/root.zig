pub const par = @import("parameter.zig");
pub const ctl = @import("control.zig");

pub const F = ctl.CSISequenceFunction;

test {
    _ = par.SGR.Color.ColorX.Color256._test;
    _ = par.SGR.Color.ColorX.ColorRGB._test;
    _ = ctl.ControlCharater._test;
    _ = ctl.ESCSequence._test;
    _ = ctl.CSISequenceFunction._test;
}
