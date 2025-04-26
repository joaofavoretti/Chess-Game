const std = @import("std");
const p = @import("piece.zig");
const b = @import("board.zig");
const m = @import("move.zig");

const Board = b.Board;
const Move = m.Move;
const PieceColor = p.PieceColor;

const EngineController = struct {
    board: *Board,
    pseudoLegalMoves: std.ArrayList(Move),

    pub fn init(board: *Board) EngineController {
        return EngineController{
            .board = board,
            .pseudoLegalMoves = std.ArrayList(Move).init(std.heap.c_allocator),
        };
    }

    pub fn deinit(self: *EngineController) void {
        self.pseudoLegalMoves.deinit();
    }

    fn generatePawnPseudoLegalMoves(self: *EngineController, colorToMove: PieceColor) void {
        _ = self;
        _ = colorToMove;
    }

    pub fn generateMoves(self: *EngineController) void {
        self.pseudoLegalMoves.clearAndFree();
        const colorToMove = self.board.pieceToMove;

        self.generatePawnPseudoLegalMoves(colorToMove);
    }
};
