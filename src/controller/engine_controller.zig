const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const b = @import("board.zig");
const r = @import("render.zig");
const m = @import("move.zig");
const mg = @import("move_gen.zig");

const Board = b.Board;
const Render = r.Render;
const Move = m.Move;
const MoveCode = m.MoveCode;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const Bitboard = b.Bitboard;
const MoveGen = mg.MoveGen;

const TIME_PER_MOVE: f32 = 10.0;

pub const EngineController = struct {
    board: *Board,
    moveGen: MoveGen = undefined,
    _madeMove: bool = false,

    // Used for visual perft testing
    lastIndexTested: i32 = -1,

    pub fn init(board: *Board) EngineController {
        return EngineController{
            .board = board,
            .moveGen = MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn copyEmpty(self: *EngineController) EngineController {
        return EngineController{
            .board = self.board,
            .moveGen = MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *EngineController) void {
        self.moveGen.deinit();
    }

    pub fn madeMove(self: *EngineController) bool {
        const ret = self._madeMove;
        self._madeMove = false;
        return ret;
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

    pub fn update(self: *EngineController, deltaTime: f32) void {
        _ = deltaTime;

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            self.makeRandomMove();
            self._madeMove = true;
            self.genMoves();
        }

        if (rl.isKeyPressed(rl.KeyboardKey.g)) {
            self.genMoves();
        }

        if (rl.isKeyPressed(rl.KeyboardKey.b)) {
            if (self.lastIndexTested != -1) {
                const lastMove = self.moveGen.pseudoLegalMoves.items[@intCast(self.lastIndexTested)];
                self.board.undoMove(lastMove);
                self.lastIndexTested = @mod((self.lastIndexTested - 1), @as(i32, @intCast(self.moveGen.pseudoLegalMoves.items.len)));
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.n)) {
            if (self.lastIndexTested != -1) {
                const lastMove = self.moveGen.pseudoLegalMoves.items[@intCast(self.lastIndexTested)];
                self.board.undoMove(lastMove);
            }

            while (true) {
                self.lastIndexTested = @mod((self.lastIndexTested + 1), @as(i32, @intCast(self.moveGen.pseudoLegalMoves.items.len)));
                const move = self.moveGen.pseudoLegalMoves.items[@intCast(self.lastIndexTested)];
                self.board.makeMove(move);

                if (mg.isKingInCheck(self.board, self.board.pieceToMove.opposite())) {
                    self.board.undoMove(move);
                } else {
                    break;
                }
            }
        }
    }
};
