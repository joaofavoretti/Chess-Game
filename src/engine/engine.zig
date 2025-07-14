const std = @import("std");
const core = @import("core");

pub const Engine = struct {
    board: *core.Board,
    moveGen: core.MoveGen,

    pub fn init(board: *core.Board) Engine {
        return Engine{
            .board = board,
            .moveGen = core.MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *Engine) void {
        self.moveGen.deinit();
    }

    pub fn setup(self: *Engine) void {
        self.moveGen.update(self.board);
    }

    pub fn onBoardChange(self: *Engine) void {
        self.moveGen.update(self.board);
    }

    // TODO: Validate the move before returning it
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

    pub fn getMove(self: *Engine) ?core.types.Move {
        if (self.moveGen.pseudoLegalMoves.items.len == 0) {
            return null;
        }

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, self.moveGen.pseudoLegalMoves.items.len);
        return self.moveGen.pseudoLegalMoves.items[randomIndex];
    }
};
