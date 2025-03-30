const std = @import("std");
const path = std.fs.path;
const rl = @import("raylib");
const IVector2 = @import("utils.zig").IVector2;

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
    pos: IVector2,
    color: PieceColor,
    pieceType: PieceType,
    texture: rl.Texture2D = undefined,

    pub fn init(pos: IVector2, color: PieceColor, pieceType: PieceType) Piece {
        if (pos.x >= 8 or pos.y >= 8) {
            return Piece{
                .pos = IVector2.init(0, 0),
                .color = PieceColor.White,
                .pieceType = PieceType.Pawn,
                .texture = rl.loadTexture(TEXTURE_DEFAULT_PATH) catch unreachable,
            };
        }

        return Piece{
            .pos = pos,
            .color = color,
            .pieceType = pieceType,
            .texture = getTexture(color, pieceType),
        };
    }

    pub fn getPossibleMoves(self: *Piece) !std.ArrayList(IVector2) {
        _ = self;

        var list = std.ArrayList(IVector2).init(std.heap.page_allocator);
        try list.append(IVector2.init(4, 4));
        try list.append(IVector2.init(4, 5));
        return list;
    }

    pub fn getSize(self: *Piece) IVector2 {
        return IVector2.init(self.texture.width, self.texture.height);
    }

    pub fn draw(self: *Piece, dest: rl.Rectangle) void {
        const tWidth = @as(f32, @floatFromInt(self.texture.width));
        const tHeight = @as(f32, @floatFromInt(self.texture.height));
        const source = rl.Rectangle.init(0, 0, tWidth, tHeight);
        const origin = rl.Vector2.init(0, 0);

        rl.drawTexturePro(self.texture, source, dest, origin, 0.0, rl.Color.white);
    }
};
