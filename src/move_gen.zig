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

fn knightAttacks(knightBitboard: Bitboard) Bitboard {
    const l1 = (knightBitboard >> 1) & 0x7f7f7f7f7f7f7f7f;
    const l2 = (knightBitboard >> 2) & 0x3f3f3f3f3f3f3f3f;
    const r1 = (knightBitboard << 1) & 0xfefefefefefefefe;
    const r2 = (knightBitboard << 2) & 0xfcfcfcfcfcfcfcfc;
    const h1 = l1 | r1;
    const h2 = l2 | r2;
    return (h1 << 16) | (h1 >> 16) | (h2 << 8) | (h2 >> 8);
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
        self.genPawnAttacks(board);
        self.genKnightMoves(board);
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

    fn genPawnAttacks(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;

        const pawnBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        const pawnEastAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnEastAttack(pawnBitboard),
            PieceColor.Black => pawnAttackUtils.blackPawnEastAttack(pawnBitboard),
        };

        const pawnWestAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnWestAttack(pawnBitboard),
            PieceColor.Black => pawnAttackUtils.blackPawnWestAttack(pawnBitboard),
        };

        var oppositeColorBitboard = board.getColorBitboard(colorToMove.opposite());

        // Check the EnPassant target square as valid
        if (board.enPassantTarget) |enPassantTarget| {
            oppositeColorBitboard |= (@as(u64, 1) << enPassantTarget);
        }

        var pawnEastAttackTarget = pawnEastAttacks & oppositeColorBitboard;
        var pawnEastAble2Capture = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnAble2CaptureEast(pawnEastAttackTarget),
            PieceColor.Black => pawnAttackUtils.blackPawnAble2CaptureEast(pawnEastAttackTarget),
        };

        while (pawnEastAttackTarget != 0 and pawnEastAble2Capture != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnEastAble2Capture));
            const targetSquare: u6 = @intCast(@ctz(pawnEastAttackTarget));

            const capturedPiece = board.getPiece(targetSquare);

            var move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            if (!capturedPiece.valid) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .EnPassant = .{
                        .capturedPiece = Piece.init(
                            colorToMove.opposite(),
                            PieceType.Pawn,
                        ),
                    } },
                );
            }

            if (isWhiteOrBlackPromotionSquare(targetSquare)) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                );
            }

            self.pseudoLegalMoves.append(move) catch unreachable;
            pawnEastAttackTarget &= ~(@as(u64, 1) << targetSquare);
            pawnEastAble2Capture &= ~(@as(u64, 1) << originSquare);
        }

        var pawnWestAttackTarget = pawnWestAttacks & oppositeColorBitboard;
        var pawnWestAble2Capture = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnAble2CaptureWest(pawnWestAttackTarget),
            PieceColor.Black => pawnAttackUtils.blackPawnAble2CaptureWest(pawnWestAttackTarget),
        };

        while (pawnWestAttackTarget != 0 and pawnWestAble2Capture != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnWestAble2Capture));
            const targetSquare: u6 = @intCast(@ctz(pawnWestAttackTarget));

            const capturedPiece = board.getPiece(targetSquare);

            var move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            // Condition to be an enPassant capture
            if (!capturedPiece.valid) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .EnPassant = .{
                        .capturedPiece = Piece.init(
                            colorToMove.opposite(),
                            PieceType.Pawn,
                        ),
                    } },
                );
            }

            // Capture with promotion
            if (isWhiteOrBlackPromotionSquare(targetSquare)) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                );
            }

            self.pseudoLegalMoves.append(move) catch unreachable;
            pawnWestAttackTarget &= ~(@as(u64, 1) << targetSquare);
            pawnWestAble2Capture &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genKnightMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var knightBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Knight)];
        const availableSquares = ~board.getColorBitboard(colorToMove);

        while (knightBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(knightBitboard));
            var attackTarget = knightAttacks(@as(u64, 1) << originSquare);
            attackTarget &= availableSquares;

            var captureTarget = attackTarget & board.getColorBitboard(colorToMove.opposite());
            attackTarget &= ~captureTarget;

            // Capture moves
            while (captureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(captureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                captureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            // Quiet moves
            while (attackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(attackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                attackTarget &= ~(@as(u64, 1) << targetSquare);
            }
            knightBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }
};
