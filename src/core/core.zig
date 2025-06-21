pub const Board = @import("board.zig").Board;
pub const MoveGen = @import("move_gen.zig").MoveGen;
pub const perft = @import("perft.zig").perft;

pub const types = @import("types/types.zig");
pub const utils = @import("utils/utils.zig");

comptime {
    _ = @import("test.zig");
}
