const core = @import("../core.zig");
const utils = @import("utils.zig");
const types = @import("../types/types.zig");

const Bitboard = types.Bitboard;
const Board = core.Board;
const PieceColor = types.PieceColor;
const PieceType = types.PieceType;

const pawnUtils = utils.pawn;
const knightUtils = utils.knight;
const rookUtils = utils.rook;
const bishopUtils = utils.bishop;
const kingUtils = utils.king;

pub fn isWhiteOrBlackPromotionSquare(targetSquare: u6) bool {
    return (targetSquare & 0b111000) == 0b111000 or
        (targetSquare ^ 0b111000) & 0b111000 == 0b111000;
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

pub fn getKingSquare(board: *Board, kingColor: PieceColor) u6 {
    const kingBitboard = board.boards[@intFromEnum(kingColor)][@intFromEnum(PieceType.King)];
    if (kingBitboard == 0) {
        return 0; // No king on the board, return an invalid square
    }
    return @intCast(@ctz(kingBitboard));
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
        PieceColor.White => pawnUtils.whitePawnAnyAttacks(opPawnBitboard),
        PieceColor.Black => pawnUtils.blackPawnAnyAttacks(opPawnBitboard),
    };

    if (pawnCaptureTarget & squareBitboard != 0) {
        return true;
    }

    if (knightUtils.knightAttacks(squareBitboard) & opKnightBitboard != 0) {
        return true;
    }

    const rookAttackTargets = rookUtils.rookAttacks(
        @intCast(@ctz(squareBitboard)),
        board.getColorBitboard(colorAttacking.opposite()),
        board.getColorBitboard(colorAttacking),
    );
    if ((rookAttackTargets & opRookBitboard != 0) or (rookAttackTargets & opQueenBitboard != 0)) {
        return true;
    }

    const bishopAttackTargets = bishopUtils.bishopAttacks(
        @intCast(@ctz(squareBitboard)),
        board.getColorBitboard(colorAttacking.opposite()),
        board.getColorBitboard(colorAttacking),
    );
    if ((bishopAttackTargets & opBishopBitboard != 0) or (bishopAttackTargets & opQueenBitboard != 0)) {
        return true;
    }

    if (kingUtils.kingAttacks(opKingBitboard) & squareBitboard != 0) {
        return true;
    }

    return false;
}
