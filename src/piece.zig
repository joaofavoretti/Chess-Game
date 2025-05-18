const std = @import("std");

pub const PieceType = enum {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
};
pub const PieceTypeLength = @typeInfo(PieceType).@"enum".fields.len;

pub const PieceColor = enum {
    White,
    Black,

    // Eventually remove this
    pub fn oposite(self: PieceColor) PieceColor {
        return if (self == PieceColor.White) PieceColor.Black else PieceColor.White;
    }

    // Correcting typo
    pub fn opposite(self: PieceColor) PieceColor {
        return if (self == PieceColor.White) PieceColor.Black else PieceColor.White;
    }
};
pub const PieceColorLength = @typeInfo(PieceColor).@"enum".fields.len;

pub const Piece = packed struct(u8) {
    color: u1 = 0,
    pieceType: u3 = 0,
    valid: bool = true,
    _padding: u3 = 0,

    pub fn init(color: PieceColor, pieceType: PieceType) Piece {
        return Piece{
            .color = @intFromEnum(color),
            .pieceType = @intFromEnum(pieceType),
        };
    }

    pub fn initInvalid() Piece {
        return Piece{
            .color = 0,
            .pieceType = 0,
            .valid = false,
            ._padding = 0,
        };
    }

    pub fn getColor(self: *const Piece) PieceColor {
        return @enumFromInt(self.color);
    }

    pub fn getPieceType(self: *const Piece) PieceType {
        return @enumFromInt(self.pieceType);
    }
};
