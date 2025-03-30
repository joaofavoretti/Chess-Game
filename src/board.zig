const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const IVector2 = @import("utils.zig").IVector2;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

pub const Board = struct {
    pieces: std.BoundedArray(Piece, 32),
    tileSize: i32,
    offsetX: i32,
    offsetY: i32,

    WHITE_TILE_COLOR: rl.Color,
    BLACK_TILE_COLOR: rl.Color,

    fn initPieces() std.BoundedArray(Piece, 32) {
        var pieces: std.BoundedArray(Piece, 32) = .{};

        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            pieces.append(Piece.init(IVector2.init(i_, 1), PieceColor.White, PieceType.Pawn)) catch unreachable;
            pieces.append(Piece.init(IVector2.init(i_, 6), PieceColor.Black, PieceType.Pawn)) catch unreachable;
        }

        pieces.append(Piece.init(IVector2.init(0, 0), PieceColor.White, PieceType.Rook)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(7, 0), PieceColor.White, PieceType.Rook)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(0, 7), PieceColor.Black, PieceType.Rook)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(7, 7), PieceColor.Black, PieceType.Rook)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(1, 0), PieceColor.White, PieceType.Knight)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(6, 0), PieceColor.White, PieceType.Knight)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(1, 7), PieceColor.Black, PieceType.Knight)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(6, 7), PieceColor.Black, PieceType.Knight)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(2, 0), PieceColor.White, PieceType.Bishop)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(5, 0), PieceColor.White, PieceType.Bishop)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(2, 7), PieceColor.Black, PieceType.Bishop)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(5, 7), PieceColor.Black, PieceType.Bishop)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(3, 0), PieceColor.White, PieceType.Queen)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(3, 7), PieceColor.Black, PieceType.Queen)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(4, 0), PieceColor.White, PieceType.King)) catch unreachable;
        pieces.append(Piece.init(IVector2.init(4, 7), PieceColor.Black, PieceType.King)) catch unreachable;

        return pieces;
    }

    pub fn init() Board {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);

        return Board{
            .WHITE_TILE_COLOR = rl.Color.init(232, 237, 249, 255),
            .BLACK_TILE_COLOR = rl.Color.init(183, 192, 216, 255),
            .pieces = initPieces(),
            .tileSize = tileSize,
            .offsetX = offsetX,
            .offsetY = offsetY,
        };
    }

    pub fn drawPiece(self: *Board, piece: *Piece, pos: IVector2) void {
        if (pos.x >= 8 or pos.y >= 8) {
            return;
        }

        const pieceSize = piece.getSize();

        if (pieceSize.x > self.tileSize or pieceSize.y > self.tileSize) {
            return;
        }

        const padding = @divTrunc(self.tileSize - pieceSize.x, 2);

        const dest = rl.Rectangle.init(
            @as(f32, @floatFromInt((self.offsetX + pos.x * self.tileSize) + padding)),
            @as(f32, @floatFromInt((self.offsetY + pos.y * self.tileSize) + padding)),
            @as(f32, @floatFromInt(pieceSize.x)),
            @as(f32, @floatFromInt(pieceSize.y)),
        );
        piece.draw(dest);
    }

    pub fn draw(self: *Board) void {
        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            for (0..8) |j| {
                const j_ = @as(i32, @intCast(j));
                const x = self.offsetX + i_ * self.tileSize;
                const y = self.offsetY + j_ * self.tileSize;

                var color = self.BLACK_TILE_COLOR;

                if ((i + j) % 2 == 0) {
                    color = self.WHITE_TILE_COLOR;
                }

                rl.drawRectangle(
                    x,
                    y,
                    self.tileSize,
                    self.tileSize,
                    color,
                );
            }
        }

        for (self.pieces.slice()) |*piece| {
            self.drawPiece(piece, piece.pos);
        }
    }
};
