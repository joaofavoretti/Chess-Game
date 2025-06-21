const types = @import("../types/types.zig");

const Bitboard = types.Bitboard;

const notAFile: Bitboard = 0xfefefefefefefefe; // ~0x0101010101010101
const notHFile: Bitboard = 0x7f7f7f7f7f7f7f7f; // ~0x8080808080808080

pub fn shiftNorth(bitboard: Bitboard) Bitboard {
    return bitboard << 8;
}

pub fn shiftSouth(bitboard: Bitboard) Bitboard {
    return bitboard >> 8;
}

pub fn shiftEast(bitboard: Bitboard) Bitboard {
    return (bitboard & notHFile) << 1;
}

pub fn shiftNortheast(bitboard: Bitboard) Bitboard {
    return (bitboard & notHFile) << 9;
}

pub fn shiftSoutheast(bitboard: Bitboard) Bitboard {
    return (bitboard & notHFile) >> 7;
}

pub fn shiftWest(bitboard: Bitboard) Bitboard {
    return (bitboard & notAFile) >> 1;
}

pub fn shiftSouthwest(bitboard: Bitboard) Bitboard {
    return (bitboard & notAFile) >> 9;
}

pub fn shiftNorthwest(bitboard: Bitboard) Bitboard {
    return (bitboard & notAFile) << 7;
}
