const board = @import("board.zig");

const Board = board.Board;

pub const Interface = struct {
    selectedBoard: ?*Board,
    boards: []const *Board,

    pub fn init(boards: []const *Board) Interface {
        if (board.leng(boards) == 0) {
            return Interface{
                .selectedBoard = null,
                .boards = boards,
            };
        }

        return Interface{
            .selectedBoard = boards[0],
            .boards = boards,
        };
    }

    pub fn run(self: *Interface) void {
        if (self.selectedBoard) |board| {
            board.run();
        } else {
            // Handle the case where no board is selected
            std.debug.print("No board selected.\n", .{});
        }
    }
};
