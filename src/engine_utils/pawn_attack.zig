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

pub fn whitePawnEastAttack(pawns: Bitboard) Bitboard {
    return Board.shiftEast(Board.shiftNorth(pawns));
}

pub fn whitePawnWestAttack(pawns: Bitboard) Bitboard {
    return Board.shiftWest(Board.shiftNorth(pawns));
}

pub fn blackPawnEastAttack(pawns: Bitboard) Bitboard {
    return Board.shiftEast(Board.shiftSouth(pawns));
}

pub fn blackPawnWestAttack(pawns: Bitboard) Bitboard {
    return Board.shiftWest(Board.shiftSouth(pawns));
}

pub fn whitePawnAnyAttacks(pawns: Bitboard) Bitboard {
    return whitePawnEastAttack(pawns) | whitePawnWestAttack(pawns);
}

pub fn whitePawnDblAttack(pawns: Bitboard) Bitboard {
    return whitePawnEastAttack(pawns) & whitePawnWestAttack(pawns);
}

pub fn whitePawnSingleAttack(pawns: Bitboard) Bitboard {
    return whitePawnEastAttack(pawns) ^ whitePawnWestAttack(pawns);
}

pub fn blackPawnAnyAttacks(pawns: Bitboard) Bitboard {
    return blackPawnEastAttack(pawns) | blackPawnWestAttack(pawns);
}

pub fn blackPawnDblAttack(pawns: Bitboard) Bitboard {
    return blackPawnEastAttack(pawns) & blackPawnWestAttack(pawns);
}

pub fn blackPawnSingleAttack(pawns: Bitboard) Bitboard {
    return blackPawnEastAttack(pawns) ^ blackPawnWestAttack(pawns);
}

pub fn whitePawnAble2CaptureEast(attackTarget: Bitboard) Bitboard {
    return Board.shiftWest(Board.shiftSouth(attackTarget));
}

pub fn whitePawnAble2CaptureWest(attackTarget: Bitboard) Bitboard {
    return Board.shiftEast(Board.shiftSouth(attackTarget));
}

pub fn blackPawnAble2CaptureEast(attackTarget: Bitboard) Bitboard {
    return Board.shiftWest(Board.shiftNorth(attackTarget));
}

pub fn blackPawnAble2CaptureWest(attackTarget: Bitboard) Bitboard {
    return Board.shiftEast(Board.shiftNorth(attackTarget));
}
