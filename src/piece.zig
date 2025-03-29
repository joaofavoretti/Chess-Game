const std = @import("std");
const path = std.fs.path;
const rl = @import("raylib");

const TEXTURE_ASSET_PATH = "./assets";
const TEXTURE_DEFAULT_PATH = "./assets/Default.png";

pub const PieceColor = enum {
    White,
    Black,
};

pub const PieceType = enum {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,
    King,
};

fn getTextureFromPiece(pieceColor: PieceColor, pieceType: PieceType) !rl.Texture2D {
    var buf: std.BoundedArray(u8, 128) = .{};
    try buf.writer().print("{s}/{s}-{s}.png", .{ TEXTURE_ASSET_PATH, @tagName(pieceType), @tagName(pieceColor) });
    try buf.append(0);
    return rl.loadTexture(@ptrCast(buf.constSlice()));
}

fn getTexture(pieceColor: PieceColor, pieceType: PieceType) rl.Texture2D {
    return getTextureFromPiece(pieceColor, pieceType) catch rl.loadTexture(TEXTURE_DEFAULT_PATH) catch unreachable;
}

pub const Piece = struct {
    color: PieceColor,
    pieceType: PieceType,
    texture: rl.Texture2D = undefined,

    pub fn init(color: PieceColor, pieceType: PieceType) Piece {
        return Piece{
            .color = color,
            .pieceType = pieceType,
            .texture = getTexture(color, pieceType),
        };
    }

    pub fn draw(self: *Piece, pos: rl.Vector2) void {
        rl.drawTextureV(self.texture, pos, rl.Color.white);
    }
};
