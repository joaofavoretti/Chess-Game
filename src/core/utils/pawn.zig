const core = @import("../core.zig");
const types = @import("../types/types.zig");
const utils = @import("../utils/utils.zig");

const shiftUtils = utils.shift;

const Board = core.Board;
const Bitboard = types.Bitboard;

pub fn whitePawnSinglePushTarget(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return shiftUtils.shiftNorth(whitePawns) & emptySquares;
}

pub fn blackPawnSinglePushTarget(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return shiftUtils.shiftSouth(blackPawns) & emptySquares;
}

pub fn whitePawnDoublePushTarget(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank4: Bitboard = 0x00000000FF000000;
    const singlePushTarget = whitePawnSinglePushTarget(whitePawns, emptySquares);
    return shiftUtils.shiftNorth(singlePushTarget) & emptySquares & rank4;
}

pub fn blackPawnDoublePushTarget(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank5: Bitboard = 0x000000FF00000000;
    const singlePushTarget = blackPawnSinglePushTarget(blackPawns, emptySquares);
    return shiftUtils.shiftSouth(singlePushTarget) & emptySquares & rank5;
}

pub fn whitePawnAble2Push(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return shiftUtils.shiftSouth(emptySquares) & whitePawns;
}

pub fn blackPawnAble2Push(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    return shiftUtils.shiftNorth(emptySquares) & blackPawns;
}

pub fn whitePawnAble2DblPush(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank4: Bitboard = 0x00000000FF000000;
    const emptyRank3: Bitboard = shiftUtils.shiftSouth(emptySquares & rank4) & emptySquares;
    return whitePawnAble2Push(whitePawns, emptyRank3);
}

pub fn blackPawnAble2DblPush(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
    const rank5: Bitboard = 0x000000FF00000000;
    const emptyRank4: Bitboard = shiftUtils.shiftNorth(emptySquares & rank5) & emptySquares;
    return blackPawnAble2Push(blackPawns, emptyRank4);
}

pub fn whitePawnEastAttack(pawns: Bitboard) Bitboard {
    return shiftUtils.shiftEast(shiftUtils.shiftNorth(pawns));
}

pub fn whitePawnWestAttack(pawns: Bitboard) Bitboard {
    return shiftUtils.shiftWest(shiftUtils.shiftNorth(pawns));
}

pub fn blackPawnEastAttack(pawns: Bitboard) Bitboard {
    return shiftUtils.shiftEast(shiftUtils.shiftSouth(pawns));
}

pub fn blackPawnWestAttack(pawns: Bitboard) Bitboard {
    return shiftUtils.shiftWest(shiftUtils.shiftSouth(pawns));
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
    return shiftUtils.shiftWest(shiftUtils.shiftSouth(attackTarget));
}

pub fn whitePawnAble2CaptureWest(attackTarget: Bitboard) Bitboard {
    return shiftUtils.shiftEast(shiftUtils.shiftSouth(attackTarget));
}

pub fn blackPawnAble2CaptureEast(attackTarget: Bitboard) Bitboard {
    return shiftUtils.shiftWest(shiftUtils.shiftNorth(attackTarget));
}

pub fn blackPawnAble2CaptureWest(attackTarget: Bitboard) Bitboard {
    return shiftUtils.shiftEast(shiftUtils.shiftNorth(attackTarget));
}
