const std = @import("std");
const rl = @import("raylib");
const Board = @import("board.zig").Board;

pub const Engine = struct {
    board: *Board,

    pub fn init(board: *Board) Engine {
        return Engine{
            .board = board,
        };
    }

    pub fn makeMove(self: *Engine) void {
        if (self.board.isGameOver) {
            std.debug.print("[Engine] Game is over, no moves can be made\n", .{});
            return;
        }

        const moves = self.board.getAllValidMoves() catch std.debug.panic("Failed to get all valid moves", .{});

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, moves.items.len);
        const move = moves.items[randomIndex];

        self.board.makeMove(move);
        moves.deinit();
    }
};
