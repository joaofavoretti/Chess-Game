pub const shift = @import("shift.zig");
pub const mask = @import("mask.zig");
pub const pawn = @import("pawn.zig");
pub const knight = @import("knight.zig");
pub const rook = @import("rook.zig");
pub const bishop = @import("bishop.zig");
pub const king = @import("king.zig");
pub const check = @import("check.zig");

const types = @import("../types/types.zig");

const Bitboard = types.Bitboard;

pub fn reverseBitscan(bb_: Bitboard) u6 {
    const index64: [64]u32 = [_]u32{
        0,  47, 1,  56, 48, 27, 2,  60,
        57, 49, 41, 37, 28, 16, 3,  61,
        54, 58, 35, 52, 50, 42, 21, 44,
        38, 32, 29, 23, 17, 11, 4,  62,
        46, 55, 26, 59, 40, 36, 15, 53,
        34, 51, 20, 43, 31, 22, 10, 45,
        25, 39, 14, 33, 19, 30, 9,  24,
        13, 18, 8,  12, 7,  6,  5,  63,
    };

    const debruijn64: u64 = 0x03f79d71b4cb0a89;
    var bb: Bitboard = bb_;
    if (bb == 0) return 0;
    bb |= bb >> 1;
    bb |= bb >> 2;
    bb |= bb >> 4;
    bb |= bb >> 8;
    bb |= bb >> 16;
    bb |= bb >> 32;
    return @intCast(index64[@mulWithOverflow(bb, debruijn64)[0] >> 58]);
}
