const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const b = @import("board.zig");
const r = @import("render.zig");
const m = @import("move.zig");
const mg = @import("move_gen.zig");
const pawnPushUtils = @import("engine_utils/pawn_push.zig");
const pawnAttackUtils = @import("engine_utils/pawn_attack.zig");

const Board = b.Board;
const Render = r.Render;
const Move = m.Move;
const MoveCode = m.MoveCode;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const Bitboard = b.Bitboard;
const MoveGen = mg.MoveGen;

pub const EngineController = struct {
    board: *Board,
    timeSinceLastMove: f32 = 0,
    moveGen: MoveGen = undefined,

    pub fn init(board: *Board) EngineController {
        return EngineController{
            .board = board,
            .moveGen = MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn copyEmpty(self: *EngineController) EngineController {
        return EngineController{
            .board = self.board,
            .timeSinceLastMove = self.timeSinceLastMove,
            .moveGen = MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *EngineController) void {
        self.moveGen.deinit();
    }

    pub fn genMoves(self: *EngineController) void {
        self.moveGen.update(self.board);
    }

    pub fn makeRandomMove(self: *EngineController) void {
        if (self.moveGen.pseudoLegalMoves.items.len == 0) {
            return;
        }

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, self.moveGen.pseudoLegalMoves.items.len);
        const move = self.moveGen.pseudoLegalMoves.items[randomIndex];
        self.board.makeMove(move);
    }

    pub fn perft(self: *EngineController, depth: usize) u32 {
        if (depth == 0) {
            return 1;
        }

        var count: u32 = 0;
        self.genMoves();

        var newEngine = self.copyEmpty();
        for (self.moveGen.pseudoLegalMoves.items) |move| {
            newEngine.board.makeMove(move);
            count += newEngine.perft(depth - 1);
            newEngine.board.undoMove(move);
        }
        return count;
    }

    pub fn update(self: *EngineController, deltaTime: f32) void {
        _ = deltaTime;

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            self.makeRandomMove();
            self.genMoves();
        }

        if (rl.isKeyPressed(rl.KeyboardKey.g)) {
            self.genMoves();
        }

        if (rl.isKeyPressed(rl.KeyboardKey.u)) {
            if (self.board.lastMoves.pop()) |lastMove| {
                self.board.undoMove(lastMove);
                self.genMoves();
            }
        }
    }
};
