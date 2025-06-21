const types = @import("../types/types.zig");
const utils = @import("utils.zig");

const Bitboard = types.Bitboard;

pub fn rookAttacks(rookSquare: u6, sameColorPieces: Bitboard, oppositeColorPieces: Bitboard) Bitboard {
    const blockers = sameColorPieces | oppositeColorPieces;

    const eastAttacksEmptyBoard = utils.mask.eastMaskEx(rookSquare);
    const eastAttackBlockers = eastAttacksEmptyBoard & blockers;
    var eastAttacks = eastAttacksEmptyBoard;
    if (eastAttackBlockers != 0) {
        const eastAttackBlockerSquare: u6 = @intCast(@ctz(eastAttackBlockers));
        eastAttacks = (eastAttacksEmptyBoard ^ utils.mask.eastMaskEx(eastAttackBlockerSquare)) & ~sameColorPieces;
    }

    const nortAttacksEmptyBoard = utils.mask.nortMaskEx(rookSquare);
    const nortAttackBlockers = nortAttacksEmptyBoard & blockers;
    var nortAttacks = nortAttacksEmptyBoard;
    if (nortAttackBlockers != 0) {
        const nortAttackBlockerSquare: u6 = @intCast(@ctz(nortAttackBlockers));
        nortAttacks = (nortAttacksEmptyBoard ^ utils.mask.nortMaskEx(nortAttackBlockerSquare)) & ~sameColorPieces;
    }

    const westAttacksEmptyBoard = utils.mask.westMaskEx(rookSquare);
    const westAttackBlockers = westAttacksEmptyBoard & blockers;
    var westAttacks = westAttacksEmptyBoard;
    if (westAttackBlockers != 0) {
        const westAttackBlockerSquare = utils.reverseBitscan(westAttackBlockers);
        westAttacks = (westAttacksEmptyBoard ^ utils.mask.westMaskEx(westAttackBlockerSquare)) & ~sameColorPieces;
    }

    const southAttacksEmptyBoard = utils.mask.southMaskEx(rookSquare);
    const southAttackBlockers = southAttacksEmptyBoard & blockers;
    var southAttacks = southAttacksEmptyBoard;
    if (southAttackBlockers != 0) {
        const southAttackBlockerSquare: u6 = utils.reverseBitscan(southAttackBlockers);
        southAttacks = (southAttacksEmptyBoard ^ utils.mask.southMaskEx(southAttackBlockerSquare)) & ~sameColorPieces;
    }

    return eastAttacks | nortAttacks | westAttacks | southAttacks;
}
