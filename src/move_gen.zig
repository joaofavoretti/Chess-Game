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

fn rankMask(square: u6) Bitboard {
    return @as(u64, 0b11111111) << @intCast(square & 0b111000);
}

fn fileMask(square: u6) Bitboard {
    return @as(u64, 0x0101010101010101) << @intCast(square & 0b111);
}

fn diagonalMask(square: u6) u64 {
    const maindia: u64 = 0x8040201008040201;
    const diag: i32 = @subWithOverflow(@as(i32, square) & 7, @as(i32, square) >> 3)[0];
    return if (diag >= 0) maindia >> @intCast(diag * 8) else maindia << @intCast(-diag * 8);
}

fn diagonalMaskEx(square: u6) Bitboard {
    return (@as(u64, 1) << square) ^ diagonalMask(square);
}

fn antiDiagonalMask(square: u6) u64 {
    const maindia: u64 = 0x0102040810204080;
    const diag: i32 = 7 - (@as(i32, square) & 7) - (@as(i32, square) >> 3);
    return if (diag >= 0) maindia >> @intCast(diag * 8) else maindia << @intCast(-diag * 8);
}

fn antiDiagonalMaskEx(sq: u6) u64 {
    return (@as(u64, 1) << sq) ^ antiDiagonalMask(sq);
}

fn eastMaskEx(square: u6) Bitboard {
    return 2 * ((@as(u64, 1) << @intCast(square | 7)) - (@as(u64, 1) << @intCast(square)));
}

fn nortMaskEx(square: u6) Bitboard {
    return @as(u64, 0x0101010101010100) << square;
}

fn westMaskEx(square: u6) Bitboard {
    const one: Bitboard = 1;
    return (one << square) - ((one << @intCast(square & 0b111000)));
}

fn southMaskEx(square: u6) Bitboard {
    return @as(u64, 0x0080808080808080) >> (square ^ 0b111111);
}

fn reverseBitscan(bb_: Bitboard) u6 {
    const debruijn64: u64 = 0x03f79d71b4cb0a89;
    var bb: Bitboard = bb_;
    if (bb == 0) return 0;
    bb |= bb >> 1;
    bb |= bb >> 2;
    bb |= bb >> 4;
    bb |= bb >> 8;
    bb |= bb >> 16;
    bb |= bb >> 32;
    return @intCast(index64[@mulWithOverflow(bb, debruijn64)[0] >> 58]);
}

fn rookAttacks(rookSquare: u6, sameColorPieces: Bitboard, oppositeColorPieces: Bitboard) Bitboard {
    const blockers = sameColorPieces | oppositeColorPieces;

    const eastAttacksEmptyBoard = eastMaskEx(rookSquare);
    const eastAttackBlockers = eastAttacksEmptyBoard & blockers;
    var eastAttacks = eastAttacksEmptyBoard;
    if (eastAttackBlockers != 0) {
        const eastAttackBlockerSquare: u6 = @intCast(@ctz(eastAttackBlockers));
        eastAttacks = (eastAttacksEmptyBoard ^ eastMaskEx(eastAttackBlockerSquare)) & ~sameColorPieces;
    }

    const nortAttacksEmptyBoard = nortMaskEx(rookSquare);
    const nortAttackBlockers = nortAttacksEmptyBoard & blockers;
    var nortAttacks = nortAttacksEmptyBoard;
    if (nortAttackBlockers != 0) {
        const nortAttackBlockerSquare: u6 = @intCast(@ctz(nortAttackBlockers));
        nortAttacks = (nortAttacksEmptyBoard ^ nortMaskEx(nortAttackBlockerSquare)) & ~sameColorPieces;
    }

    const westAttacksEmptyBoard = westMaskEx(rookSquare);
    const westAttackBlockers = westAttacksEmptyBoard & blockers;
    var westAttacks = westAttacksEmptyBoard;
    if (westAttackBlockers != 0) {
        const westAttackBlockerSquare = reverseBitscan(westAttackBlockers);
        westAttacks = (westAttacksEmptyBoard ^ westMaskEx(westAttackBlockerSquare)) & ~sameColorPieces;
    }

    const southAttacksEmptyBoard = southMaskEx(rookSquare);
    const southAttackBlockers = southAttacksEmptyBoard & blockers;
    var southAttacks = southAttacksEmptyBoard;
    if (southAttackBlockers != 0) {
        const southAttackBlockerSquare: u6 = reverseBitscan(southAttackBlockers);
        southAttacks = (southAttacksEmptyBoard ^ southMaskEx(southAttackBlockerSquare)) & ~sameColorPieces;
    }

    return eastAttacks | nortAttacks | westAttacks | southAttacks;
}

fn bishopAttacks(bishopSquare: u6, sameColorPieces: Bitboard, oppositeColorPieces: Bitboard) Bitboard {
    const blockers = sameColorPieces | oppositeColorPieces;

    const mainDiagonal = diagonalMaskEx(bishopSquare);
    const antiDiagonal = antiDiagonalMaskEx(bishopSquare);

    const noEastAttackEmptyBoard = mainDiagonal & positiveMask(bishopSquare);
    const noEastAttackBlockers = noEastAttackEmptyBoard & blockers;
    var noEastAttacks = noEastAttackEmptyBoard;
    if (noEastAttackBlockers != 0) {
        const noEastAttackBlockerSquare: u6 = @intCast(@ctz(noEastAttackBlockers));
        noEastAttacks = (noEastAttackEmptyBoard ^ (diagonalMaskEx(noEastAttackBlockerSquare) & positiveMask(noEastAttackBlockerSquare))) & ~sameColorPieces;
    }

    const noWestAttackEmptyBoard = antiDiagonal & positiveMask(bishopSquare);
    const noWestAttackBlockers = noWestAttackEmptyBoard & blockers;
    var noWestAttacks = noWestAttackEmptyBoard;
    if (noWestAttackBlockers != 0) {
        const noWestAttackBlockerSquare: u6 = @intCast(@ctz(noWestAttackBlockers));
        noWestAttacks = (noWestAttackEmptyBoard ^ (antiDiagonalMaskEx(noWestAttackBlockerSquare) & positiveMask(noWestAttackBlockerSquare))) & ~sameColorPieces;
    }

    const soEastAttackEmptyBoard = mainDiagonal & negativeMask(bishopSquare);
    const soEastAttackBlockers = soEastAttackEmptyBoard & blockers;
    var soEastAttacks = soEastAttackEmptyBoard;
    if (soEastAttackBlockers != 0) {
        const soEastAttackBlockerSquare: u6 = reverseBitscan(soEastAttackBlockers);
        soEastAttacks = (soEastAttackEmptyBoard ^ (diagonalMaskEx(soEastAttackBlockerSquare) & negativeMask(soEastAttackBlockerSquare))) & ~sameColorPieces;
    }

    const soWestAttackEmptyBoard = antiDiagonal & negativeMask(bishopSquare);
    const soWestAttackBlockers = soWestAttackEmptyBoard & blockers;
    var soWestAttacks = soWestAttackEmptyBoard;
    if (soWestAttackBlockers != 0) {
        const soWestAttackBlockerSquare: u6 = reverseBitscan(soWestAttackBlockers);
        soWestAttacks = (soWestAttackEmptyBoard ^ (antiDiagonalMaskEx(soWestAttackBlockerSquare) & negativeMask(soWestAttackBlockerSquare))) & ~sameColorPieces;
    }

    return noEastAttacks | noWestAttacks | soEastAttacks | soWestAttacks;
}

fn positiveMask(square: u6) Bitboard {
    return @as(u64, @bitCast(@as(i64, -2))) << square;
}

fn negativeMask(square: u6) Bitboard {
    return (@as(u64, 1) << square) - 1;
}

pub fn areSquaresAttacked(bitboard: Bitboard, board: *Board, colorAttacking: PieceColor) bool {
    var bb = bitboard;
    while (bb != 0) {
        const square: u6 = @intCast(@ctz(bb));
        if (isSquareAttacked(square, board, colorAttacking)) {
            return true;
        }
        bb &= ~(@as(u64, 1) << square);
    }
    return false;
}

pub fn isKingInCheck(board: *Board, kingColor: PieceColor) bool {
    const kingBitboard = board.boards[@intFromEnum(kingColor)][@intFromEnum(PieceType.King)];

    if (kingBitboard == 0) {
        return true; // No king on the board, considered as in check
    }

    const kingSquare: u6 = @intCast(@ctz(kingBitboard));
    return isSquareAttacked(kingSquare, board, kingColor.opposite());
}

pub fn isSquareAttacked(square: u6, board: *Board, colorAttacking: PieceColor) bool {
    const squareBitboard = @as(u64, 1) << square;

    const opPawnBitboard = board.boards[@intFromEnum(colorAttacking)][@intFromEnum(PieceType.Pawn)];
    const opKnightBitboard = board.boards[@intFromEnum(colorAttacking)][@intFromEnum(PieceType.Knight)];
    const opBishopBitboard = board.boards[@intFromEnum(colorAttacking)][@intFromEnum(PieceType.Bishop)];
    const opRookBitboard = board.boards[@intFromEnum(colorAttacking)][@intFromEnum(PieceType.Rook)];
    const opQueenBitboard = board.boards[@intFromEnum(colorAttacking)][@intFromEnum(PieceType.Queen)];
    const opKingBitboard = board.boards[@intFromEnum(colorAttacking)][@intFromEnum(PieceType.King)];

    // Figuring out pawn attacks
    const pawnCaptureTarget = switch (colorAttacking) {
        PieceColor.White => pawnAttackUtils.whitePawnAnyAttacks(opPawnBitboard),
        PieceColor.Black => pawnAttackUtils.blackPawnAnyAttacks(opPawnBitboard),
    };

    if (pawnCaptureTarget & squareBitboard != 0) {
        return true;
    }

    if (knightAttacks(squareBitboard) & opKnightBitboard != 0) {
        return true;
    }

    const rookAttackTargets = rookAttacks(
        @intCast(@ctz(squareBitboard)),
        board.getColorBitboard(colorAttacking.opposite()),
        board.getColorBitboard(colorAttacking),
    );
    if ((rookAttackTargets & opRookBitboard != 0) or (rookAttackTargets & opQueenBitboard != 0)) {
        return true;
    }

    const bishopAttackTargets = bishopAttacks(
        @intCast(@ctz(squareBitboard)),
        board.getColorBitboard(colorAttacking.opposite()),
        board.getColorBitboard(colorAttacking),
    );
    if ((bishopAttackTargets & opBishopBitboard != 0) or (bishopAttackTargets & opQueenBitboard != 0)) {
        return true;
    }

    if (kingAttacks(opKingBitboard) & squareBitboard != 0) {
        return true;
    }

    return false;
}

fn kingAttacks(kingBitboard: Bitboard) Bitboard {
    var kingSet = kingBitboard;
    var attacks = Board.shiftEast(kingSet) | Board.shiftWest(kingSet);
    kingSet |= attacks;
    attacks |= Board.shiftNorth(kingSet) | Board.shiftSouth(kingSet);
    return attacks;
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
        self.genRookMoves(board);
        self.genBishopMoves(board);
        self.genQueenMoves(board);
        self.genKingMoves(board);
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

    fn genRookMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var rookBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Rook)];

        while (rookBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(rookBitboard));

            var attackTarget = rookAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );

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

            // Quiet Moves
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

            rookBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genBishopMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var bishopBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Bishop)];

        while (bishopBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(bishopBitboard));

            var attackTarget = bishopAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );

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

            bishopBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genQueenMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var queenBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Queen)];

        while (queenBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(queenBitboard));

            var rookAttackTarget = rookAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            ) | bishopAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );
            var rookCaptureTarget = rookAttackTarget & board.getColorBitboard(colorToMove.opposite());
            rookAttackTarget &= ~rookCaptureTarget;

            // Capture moves
            while (rookCaptureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(rookCaptureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                rookCaptureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            // Quiet Moves
            while (rookAttackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(rookAttackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                rookAttackTarget &= ~(@as(u64, 1) << targetSquare);
            }

            var bishopAttackTarget = bishopAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );
            var bishopCaptureTarget = bishopAttackTarget & board.getColorBitboard(colorToMove.opposite());
            bishopAttackTarget &= ~bishopCaptureTarget;

            // Capture moves
            while (bishopCaptureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(bishopCaptureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                bishopCaptureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            while (bishopAttackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(bishopAttackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                bishopAttackTarget &= ~(@as(u64, 1) << targetSquare);
            }

            queenBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genKingMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        const kingBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.King)];
        const availableSquares = ~board.getColorBitboard(colorToMove);
        const occupiedSquares = board.getColorBitboard(colorToMove) |
            board.getColorBitboard(colorToMove.opposite());

        if (kingBitboard == 0) {
            return;
        }

        // Obtaining king attacks
        const originSquare: u6 = @intCast(@ctz(kingBitboard));
        var attackTarget = kingAttacks(kingBitboard) & availableSquares;
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

        // Quiet Moves
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

        const castlingRightsMask = switch (colorToMove) {
            PieceColor.White => @as(u8, 0b00000011),
            PieceColor.Black => @as(u8, 0b00001100),
        };
        const castlingRights = (board.castlingRights & castlingRightsMask) >> @intCast(@ctz(castlingRightsMask));

        if (castlingRights == 0) {
            return;
        }

        // Can castle king side - east
        if (castlingRights & 0b01 != 0) {
            const eastCastleMask = Board.shiftEast(kingBitboard) |
                Board.shiftEast(Board.shiftEast(kingBitboard));

            const haveIntermediaryCheck = areSquaresAttacked(
                eastCastleMask,
                board,
                board.pieceToMove.opposite(),
            );

            if (!haveIntermediaryCheck and ~occupiedSquares & eastCastleMask == eastCastleMask) {
                const targetSquare: u6 = @intCast(@ctz(Board.shiftEast(Board.shiftEast(kingBitboard))));
                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .KingCastle = .{} },
                );
                self.pseudoLegalMoves.append(move) catch unreachable;
            }
        }

        // Can castle queen side - west
        if (castlingRights & 0b10 != 0) {
            const westCastleMask = Board.shiftWest(kingBitboard) |
                Board.shiftWest(Board.shiftWest(kingBitboard)) |
                Board.shiftWest(Board.shiftWest(Board.shiftWest(kingBitboard)));

            const westCastleCheckMask = Board.shiftWest(kingBitboard) |
                Board.shiftWest(Board.shiftWest(kingBitboard));
            const haveIntermediaryCheck = areSquaresAttacked(
                westCastleCheckMask,
                board,
                board.pieceToMove.opposite(),
            );

            if (!haveIntermediaryCheck and ~occupiedSquares & westCastleMask == westCastleMask) {
                const targetSquare: u6 = @intCast(@ctz(Board.shiftWest(Board.shiftWest(kingBitboard))));
                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenCastle = .{} },
                );
                self.pseudoLegalMoves.append(move) catch unreachable;
            }
        }
    }
};
