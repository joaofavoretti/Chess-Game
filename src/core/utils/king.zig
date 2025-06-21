const utils = @import("utils.zig");
const types = @import("../types/types.zig");

const Bitboard = types.Bitboard;

const shiftUtils = utils.shift;

pub fn kingAttacks(kingBitboard: Bitboard) Bitboard {
    var kingSet = kingBitboard;
    var attacks = shiftUtils.shiftEast(kingSet) | shiftUtils.shiftWest(kingSet);
    kingSet |= attacks;
    attacks |= shiftUtils.shiftNorth(kingSet) | shiftUtils.shiftSouth(kingSet);
    return attacks;
}
