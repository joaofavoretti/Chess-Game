const std = @import("std");
const core = @import("core.zig");
const utils = @import("utils/utils.zig");

const MoveGen = core.MoveGen;
const Board = core.Board;

pub fn perft(board: *Board, depth: usize) usize {
    if (depth == 0) {
        return 1;
    }

    var count: usize = 0;
    var moveGen = MoveGen.init(std.heap.page_allocator);
    defer moveGen.deinit();
    moveGen.update(board);
    for (moveGen.pseudoLegalMoves.items) |move| {
        board.makeMove(move);

        if (!utils.check.isKingInCheck(board, board.pieceToMove.opposite())) {
            count += perft(board, depth - 1);
        }

        board.undoMove(move);
    }
    return count;
}

// TODO: Add a test function here to see how does it work
// Add all the tests from the wikipedia to check if the engine is working

// pub fn divide(self: *EngineController, depth: usize) void {
//     if (depth < 1) {
//         std.debug.print("Divide only allowed for depth >= 1\n", .{});
//     }
//
//     self.genMoves();
//     var newEngine = self.copyEmpty();
//     std.debug.print("Perft {}\n", .{depth - 1});
//     for (self.moveGen.pseudoLegalMoves.items) |move| {
//         newEngine.board.makeMove(move);
//
//         if (!mg.isKingInCheck(newEngine.board, newEngine.board.pieceToMove.opposite())) {
//             const count = newEngine.perft(depth - 1);
//             if (move.getCode().isPromotion()) {
//                 std.debug.print("{s}{s}: {}\n", .{
//                     move.getMoveName(),
//                     move.getPromotionPieceType().getName(),
//                     count,
//                 });
//             } else {
//                 std.debug.print("{s}: {}\n", .{ move.getMoveName(), count });
//             }
//         }
//
//         newEngine.board.undoMove(move);
//     }
//     newEngine.deinit();
// }
