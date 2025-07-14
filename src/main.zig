const std = @import("std");
const core = @import("core");
const view = @import("view");

pub fn main() !void {
    var interface = view.Interface.init();
    defer interface.deinit();
    interface.run();
}
