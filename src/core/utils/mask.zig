const types = @import("../types/types.zig");

const Bitboard = types.Bitboard;

pub fn rankMask(square: u6) Bitboard {
    return @as(u64, 0b11111111) << @intCast(square & 0b111000);
}

pub fn fileMask(square: u6) Bitboard {
    return @as(u64, 0x0101010101010101) << @intCast(square & 0b111);
}

pub fn diagonalMask(square: u6) u64 {
    const maindia: u64 = 0x8040201008040201;
    const diag: i32 = @subWithOverflow(@as(i32, square) & 7, @as(i32, square) >> 3)[0];
    return if (diag >= 0) maindia >> @intCast(diag * 8) else maindia << @intCast(-diag * 8);
}

pub fn diagonalMaskEx(square: u6) Bitboard {
    return (@as(u64, 1) << square) ^ diagonalMask(square);
}

pub fn antiDiagonalMask(square: u6) u64 {
    const maindia: u64 = 0x0102040810204080;
    const diag: i32 = 7 - (@as(i32, square) & 7) - (@as(i32, square) >> 3);
    return if (diag >= 0) maindia >> @intCast(diag * 8) else maindia << @intCast(-diag * 8);
}

pub fn antiDiagonalMaskEx(sq: u6) u64 {
    return (@as(u64, 1) << sq) ^ antiDiagonalMask(sq);
}

pub fn eastMaskEx(square: u6) Bitboard {
    return 2 * ((@as(u64, 1) << @intCast(square | 7)) - (@as(u64, 1) << @intCast(square)));
}

pub fn nortMaskEx(square: u6) Bitboard {
    return @as(u64, 0x0101010101010100) << square;
}

pub fn westMaskEx(square: u6) Bitboard {
    const one: Bitboard = 1;
    return (one << square) - ((one << @intCast(square & 0b111000)));
}

pub fn southMaskEx(square: u6) Bitboard {
    return @as(u64, 0x0080808080808080) >> (square ^ 0b111111);
}

pub fn positiveMask(square: u6) Bitboard {
    return @as(u64, @bitCast(@as(i64, -2))) << square;
}

pub fn negativeMask(square: u6) Bitboard {
    return (@as(u64, 1) << square) - 1;
}
