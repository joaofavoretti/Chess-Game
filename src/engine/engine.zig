const std = @import("std");
const core = @import("core");

pub const Engine = struct {
    board: *core.Board,

    pub fn init(board: *core.Board) Engine {
        return Engine{
            .board = board,
        };
    }

    fn makeRandomMove(self: *Engine) void {
        if (self.moveGen.pseudoLegalMoves.items.len == 0) {
            return;
        }

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, self.moveGen.pseudoLegalMoves.items.len);
        const move = self.moveGen.pseudoLegalMoves.items[randomIndex];
        self.board.makeMove(move);
    }

    pub fn getMove(self: *Engine, pseudoLegalMoves: *std.ArrayList(core.Move)) ?core.Move {
        _ = self;

        if (pseudoLegalMoves.items.len == 0) {
            return null;
        }

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, pseudoLegalMoves.items.len);
        return pseudoLegalMoves.items[randomIndex];
    }
};
