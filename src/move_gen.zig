const std = @import("std");
const p = @import("piece.zig");
const b = @import("board.zig");
const r = @import("render.zig");
const m = @import("move.zig");
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

// Used for reverseBitscan stuff
const index64: [64]u32 = [_]u32{
    0,  47, 1,  56, 48, 27, 2,  60,
    57, 49, 41, 37, 28, 16, 3,  61,
    54, 58, 35, 52, 50, 42, 21, 44,
    38, 32, 29, 23, 17, 11, 4,  62,
    46, 55, 26, 59, 40, 36, 15, 53,
    34, 51, 20, 43, 31, 22, 10, 45,
    25, 39, 14, 33, 19, 30, 9,  24,
    13, 18, 8,  12, 7,  6,  5,  63,
};

fn isWhiteOrBlackPromotionSquare(targetSquare: u6) bool {
    return (targetSquare & 0b111000) == 0b111000 or
        (targetSquare ^ 0b111000) & 0b111000 == 0b111000;
}

pub const MoveGen = struct {
    pseudoLegalMoves: std.ArrayList(Move),

    pub fn init(allocator: std.mem.Allocator) MoveGen {
        return MoveGen{
            .pseudoLegalMoves = std.ArrayList(Move).init(allocator),
        };
    }

    pub fn deinit(self: *MoveGen) void {
        self.pseudoLegalMoves.deinit();
    }

    pub fn clear(self: *MoveGen) void {
        self.pseudoLegalMoves.clearRetainingCapacity();
    }

    pub fn update(self: *MoveGen, board: *Board) void {
        self.clear();
        self.genPawnPushes(board);
    }

    fn genPawnPushes(self: *MoveGen, board: *Board) void {
        const emptySquares = board.getEmptySquares();
        const colorToMove = board.pieceToMove;

        const pawnBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        var singlePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnSinglePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnSinglePushTarget(pawnBitboard, emptySquares),
        };
        var doublePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnDoublePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnDoublePushTarget(pawnBitboard, emptySquares),
        };

        var pawnAble2Push: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnAble2Push(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnAble2Push(pawnBitboard, emptySquares),
        };
        var pawnAble2DblPush: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnAble2DblPush(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnAble2DblPush(pawnBitboard, emptySquares),
        };

        // Generate quiet single push pawn moves
        while (singlePushTarget != 0 and pawnAble2Push != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnAble2Push));
            const targetSquare: u6 = @intCast(@ctz(singlePushTarget));

            var move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .QuietMove = .{} },
            );

            if (isWhiteOrBlackPromotionSquare(targetSquare)) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenPromotion = .{} },
                );
            }

            self.pseudoLegalMoves.append(move) catch unreachable;
            singlePushTarget &= ~(@as(u64, 1) << targetSquare);
            pawnAble2Push &= ~(@as(u64, 1) << originSquare);
        }

        // Generate quiet double push pawn moves
        while (doublePushTarget != 0 and pawnAble2DblPush != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnAble2DblPush));
            const targetSquare: u6 = @intCast(@ctz(doublePushTarget));
            const move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .DoublePawnPush = .{} },
            );
            self.pseudoLegalMoves.append(move) catch unreachable;
            doublePushTarget &= ~(@as(u64, 1) << targetSquare);
            pawnAble2DblPush &= ~(@as(u64, 1) << originSquare);
        }
    }
};
