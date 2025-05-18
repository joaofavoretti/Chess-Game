const std = @import("std");
const p = @import("../piece.zig");
const b = @import("../board.zig");
const r = @import("../render.zig");
const m = @import("../move.zig");

const Board = b.Board;
const Render = r.Render;
const Move = m.Move;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const Bitboard = b.Bitboard;

pub fn whitePawnSinglePushTarget(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return Board.shiftNorth(whitePawns) & emptySquares;
}

pub fn blackPawnSinglePushTarget(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return Board.shiftSouth(blackPawns) & emptySquares;
}

pub fn whitePawnDoublePushTarget(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank4: Bitboard = 0x00000000FF000000;
    const singlePushTarget = whitePawnSinglePushTarget(whitePawns, emptySquares);
    return Board.shiftNorth(singlePushTarget) & emptySquares & rank4;
}

pub fn blackPawnDoublePushTarget(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank5: Bitboard = 0x000000FF00000000;
    const singlePushTarget = blackPawnSinglePushTarget(blackPawns, emptySquares);
    return Board.shiftSouth(singlePushTarget) & emptySquares & rank5;
}

pub fn whitePawnAble2Push(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return Board.shiftSouth(emptySquares) & whitePawns;
}

pub fn blackPawnAble2Push(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return Board.shiftNorth(emptySquares) & blackPawns;
}

pub fn whitePawnAble2DblPush(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank4: Bitboard = 0x00000000FF000000;
    const emptyRank3: Bitboard = Board.shiftSouth(emptySquares & rank4) & emptySquares;
    return whitePawnAble2Push(whitePawns, emptyRank3);
}

pub fn blackPawnAble2DblPush(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank5: Bitboard = 0x000000FF00000000;
    const emptyRank4: Bitboard = Board.shiftNorth(emptySquares & rank5) & emptySquares;
    return blackPawnAble2Push(blackPawns, emptyRank4);
}
