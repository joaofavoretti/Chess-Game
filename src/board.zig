const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

pub const Board = struct {
    piece: Piece = undefined,

    WHITE_TILE_COLOR: rl.Color,
    BLACK_TILE_COLOR: rl.Color,

    pub fn init() Board {
        return Board{
            .WHITE_TILE_COLOR = rl.Color.init(232, 237, 249, 255),
            .BLACK_TILE_COLOR = rl.Color.init(183, 192, 216, 255),
            .piece = Piece.init(PieceColor.White, PieceType.Pawn),
        };
    }

    pub fn draw(self: *Board) void {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);

        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            for (0..8) |j| {
                const j_ = @as(i32, @intCast(j));
                const x = offsetX + i_ * tileSize;
                const y = offsetY + j_ * tileSize;

                var color = self.BLACK_TILE_COLOR;

                if ((i + j) % 2 == 0) {
                    color = self.WHITE_TILE_COLOR;
                }

                rl.drawRectangle(
                    x,
                    y,
                    tileSize,
                    tileSize,
                    color,
                );
            }
        }

        self.piece.draw(rl.Vector2.init(0, 0));
    }
};
