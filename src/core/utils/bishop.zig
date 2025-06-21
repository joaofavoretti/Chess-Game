const types = @import("../types/types.zig");
const utils = @import("utils.zig");

const Bitboard = types.Bitboard;

pub fn bishopAttacks(bishopSquare: u6, sameColorPieces: Bitboard, oppositeColorPieces: Bitboard) Bitboard {
    const blockers = sameColorPieces | oppositeColorPieces;

    const mainDiagonal = utils.mask.diagonalMaskEx(bishopSquare);
    const antiDiagonal = utils.mask.antiDiagonalMaskEx(bishopSquare);

    const noEastAttackEmptyBoard = mainDiagonal & utils.mask.positiveMask(bishopSquare);
    const noEastAttackBlockers = noEastAttackEmptyBoard & blockers;
    var noEastAttacks = noEastAttackEmptyBoard;
    if (noEastAttackBlockers != 0) {
        const noEastAttackBlockerSquare: u6 = @intCast(@ctz(noEastAttackBlockers));
        noEastAttacks = (noEastAttackEmptyBoard ^ (utils.mask.diagonalMaskEx(noEastAttackBlockerSquare) & utils.mask.positiveMask(noEastAttackBlockerSquare))) & ~sameColorPieces;
    }

    const noWestAttackEmptyBoard = antiDiagonal & utils.mask.positiveMask(bishopSquare);
    const noWestAttackBlockers = noWestAttackEmptyBoard & blockers;
    var noWestAttacks = noWestAttackEmptyBoard;
    if (noWestAttackBlockers != 0) {
        const noWestAttackBlockerSquare: u6 = @intCast(@ctz(noWestAttackBlockers));
        noWestAttacks = (noWestAttackEmptyBoard ^ (utils.mask.antiDiagonalMaskEx(noWestAttackBlockerSquare) & utils.mask.positiveMask(noWestAttackBlockerSquare))) & ~sameColorPieces;
    }

    const soEastAttackEmptyBoard = mainDiagonal & utils.mask.negativeMask(bishopSquare);
    const soEastAttackBlockers = soEastAttackEmptyBoard & blockers;
    var soEastAttacks = soEastAttackEmptyBoard;
    if (soEastAttackBlockers != 0) {
        const soEastAttackBlockerSquare: u6 = utils.reverseBitscan(soEastAttackBlockers);
        soEastAttacks = (soEastAttackEmptyBoard ^ (utils.mask.diagonalMaskEx(soEastAttackBlockerSquare) & utils.mask.negativeMask(soEastAttackBlockerSquare))) & ~sameColorPieces;
    }

    const soWestAttackEmptyBoard = antiDiagonal & utils.mask.negativeMask(bishopSquare);
    const soWestAttackBlockers = soWestAttackEmptyBoard & blockers;
    var soWestAttacks = soWestAttackEmptyBoard;
    if (soWestAttackBlockers != 0) {
        const soWestAttackBlockerSquare: u6 = utils.reverseBitscan(soWestAttackBlockers);
        soWestAttacks = (soWestAttackEmptyBoard ^ (utils.mask.antiDiagonalMaskEx(soWestAttackBlockerSquare) & utils.mask.negativeMask(soWestAttackBlockerSquare))) & ~sameColorPieces;
    }

    return noEastAttacks | noWestAttacks | soEastAttacks | soWestAttacks;
}
