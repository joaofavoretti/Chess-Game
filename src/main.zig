const std = @import("std");
const core = @import("core");
const view = @import("view");

pub fn main() !void {
    var board = core.Board.init();
    var interface = view.Interface.init(&board);
    interface.run();
}
