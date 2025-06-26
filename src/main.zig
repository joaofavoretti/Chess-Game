const std = @import("std");
const core = @import("core");
const view = @import("view");

pub fn main() !void {
    var board = core.Board.init();
    board.makeMove(
        core.types.Move.init(8, 16, &board, .{ .QuietMove = .{} }),
    );
    var interface = view.Interface.init(&board);
    interface.run();
}
