const std = @import("std");
const path = std.fs.path;
const rl = @import("raylib");
const IVector2 = @import("utils/ivector.zig").IVector2;

const TEXTURE_ASSET_PATH = "./assets/pieces/default";
const TEXTURE_DEFAULT_PATH = TEXTURE_ASSET_PATH ++ "/Default.png";

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
    const texture = getTextureFromPiece(pieceColor, pieceType) catch rl.loadTexture(TEXTURE_DEFAULT_PATH) catch unreachable;
    rl.setTextureFilter(texture, rl.TextureFilter.bilinear);
    return texture;
}

pub const Piece = struct {
    boardPos: IVector2,
    color: PieceColor,
    pieceType: PieceType,
    texture: ?rl.Texture2D = null,

    pub fn init(boardPos: IVector2, color: PieceColor, pieceType: PieceType) Piece {
        if (boardPos.x >= 8 or boardPos.y >= 8) {
            return Piece{
                .boardPos = IVector2.init(0, 0),
                .color = PieceColor.White,
                .pieceType = PieceType.Pawn,
                .texture = rl.loadTexture(TEXTURE_DEFAULT_PATH) catch unreachable,
            };
        }

        const texture = getTexture(color, pieceType);

        return Piece{
            .boardPos = boardPos,
            .color = color,
            .pieceType = pieceType,
            .texture = texture,
        };
    }

    pub fn deinit(self: *Piece) void {
        if (self.texture) |texture| {
            rl.unloadTexture(texture);
            self.texture = null;
        }
    }

    pub fn initUndrawable(boardPos: IVector2, color: PieceColor, pieceType: PieceType) Piece {
        return Piece{
            .boardPos = boardPos,
            .color = color,
            .pieceType = pieceType,
        };
    }

    pub fn getCopy(self: *Piece) Piece {
        return Piece{
            .boardPos = self.boardPos,
            .color = self.color,
            .pieceType = self.pieceType,
            .texture = self.texture,
        };
    }

    pub fn getSize(self: *Piece) IVector2 {
        if (self.texture) |texture| {
            return IVector2.init(texture.width, texture.height);
        }
        return IVector2.init(0, 0);
    }

    pub fn setType(self: *Piece, pieceType: PieceType) void {
        self.pieceType = pieceType;

        if (self.texture) |texture| {
            rl.unloadTexture(texture);
            self.texture = getTexture(self.color, pieceType);
        }
    }

    pub fn draw(self: *Piece, dest: rl.Rectangle) void {
        if (self.texture) |texture| {
            const tWidth = @as(f32, @floatFromInt(texture.width));
            const tHeight = @as(f32, @floatFromInt(texture.height));
            const source = rl.Rectangle.init(0, 0, tWidth, tHeight);
            const origin = rl.Vector2.init(0, 0);

            rl.drawTexturePro(texture, source, dest, origin, 0.0, rl.Color.white);
        }
    }
};
