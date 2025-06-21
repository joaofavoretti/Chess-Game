const types = @import("../types/types.zig");

const Bitboard = types.Bitboard;

pub fn knightAttacks(knightBitboard: Bitboard) Bitboard {
    const l1 = (knightBitboard >> 1) & 0x7f7f7f7f7f7f7f7f;
    const l2 = (knightBitboard >> 2) & 0x3f3f3f3f3f3f3f3f;
    const r1 = (knightBitboard << 1) & 0xfefefefefefefefe;
    const r2 = (knightBitboard << 2) & 0xfcfcfcfcfcfcfcfc;
    const h1 = l1 | r1;
    const h2 = l2 | r2;
    return (h1 << 16) | (h1 >> 16) | (h2 << 8) | (h2 >> 8);
}
