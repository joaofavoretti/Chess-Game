const std = @import("std");
const core = @import("core");
const rl = @import("raylib");

const PieceColorLength = core.types.PieceColorLength;
const PieceTypeLength = core.types.PieceTypeLength;
const PieceType = core.types.PieceType;
const PieceColor = core.types.PieceColor;
const Piece = core.types.Piece;
const IVector2 = core.types.IVector2;
const Board = core.Board;
const Bitboard = core.types.Bitboard;
const Move = core.types.Move;

const TEXTURE_ASSET_PATH = "./assets/pieces/default";
const TEXTURE_DEFAULT_PATH = TEXTURE_ASSET_PATH ++ "/Default.png";

pub const Render = struct {
    WHITE_TILE_COLOR: rl.Color = rl.Color.init(235, 236, 208, 255),
    BLACK_TILE_COLOR: rl.Color = rl.Color.init(115, 149, 82, 255),
    ACTIVE_WHITE_TILE_COLOR: rl.Color = rl.Color.init(245, 246, 130, 255),
    ACTIVE_BLACK_TILE_COLOR: rl.Color = rl.Color.init(185, 202, 67, 255),
    POSSIBLE_MOVE_COLOR: rl.Color = rl.Color.init(0, 0, 0, 30),

    textures: [PieceColorLength][PieceTypeLength]rl.Texture2D,
    tileSize: i32,
    offset: IVector2,
    inverted: bool = false,

    fn getTextureFromPiece(pieceColor: PieceColor, pieceType: PieceType) !rl.Texture2D {
        var buf: std.BoundedArray(u8, 128) = .{};
        try buf.writer().print("{s}/{s}-{s}.png", .{ TEXTURE_ASSET_PATH, @tagName(pieceType), @tagName(pieceColor) });
        try buf.append(0);
        return rl.loadTexture(@ptrCast(buf.constSlice()));
    }

    fn getTexture(pieceColor: PieceColor, pieceType: PieceType) rl.Texture2D {
        const texture = Render.getTextureFromPiece(pieceColor, pieceType) catch rl.loadTexture(TEXTURE_DEFAULT_PATH) catch unreachable;
        rl.setTextureFilter(texture, rl.TextureFilter.bilinear);
        return texture;
    }

    pub fn init() Render {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);
        var textures: [PieceColorLength][PieceTypeLength]rl.Texture2D = undefined;

        for (0..PieceColorLength) |color| {
            for (0..PieceTypeLength) |piece| {
                const pieceColor: PieceColor = @enumFromInt(color);
                const pieceType: PieceType = @enumFromInt(piece);
                textures[color][piece] = Render.getTexture(pieceColor, pieceType);
            }
        }

        return Render{
            .textures = textures,
            .tileSize = tileSize,
            .offset = IVector2.init(offsetX, offsetY),
        };
    }

    pub fn deinit(self: *Render) void {
        for (0..PieceColorLength) |color| {
            for (0..PieceTypeLength) |piece| {
                rl.unloadTexture(self.textures[color][piece]);
            }
        }
    }

    fn isWhiteTile(self: *Render, square: u6) bool {
        const pos = self.getPosFromSquare(square);
        return (@mod((pos.x + pos.y), 2) == 1);
    }

    pub fn isMouseOverBoard(self: *Render) bool {
        const rlPos = rl.getMousePosition();
        const mousePos = IVector2.fromVector2(core.types.Vector2.init(rlPos.x, rlPos.y));
        return (mousePos.x >= self.offset.x and
            mousePos.x < self.offset.x + self.tileSize * 8 and
            mousePos.y >= self.offset.y and
            mousePos.y < self.offset.y + self.tileSize * 8);
    }

    pub fn getMousePosition(self: *Render) IVector2 {
        if (!self.isMouseOverBoard()) {
            return IVector2.init(0, 0);
        }

        const rlPos = rl.getMousePosition();
        const mousePos = IVector2.fromVector2(core.types.Vector2.init(rlPos.x, rlPos.y));
        const x = @as(u6, @intCast(@divFloor(mousePos.x - self.offset.x, self.tileSize)));
        const y = @as(u6, @intCast(@divFloor(mousePos.y - self.offset.y, self.tileSize)));
        return IVector2.init(x, y);
    }

    pub fn isPosValid(_: *Render, pos: IVector2) bool {
        return (pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8);
    }

    pub fn getPosFromSquare(self: *Render, square: u6) IVector2 {
        var pos = IVector2.init(square % 8, square / 8);
        if (!self.inverted) {
            pos.x = (7 - pos.x);
        }

        if (self.inverted) {
            pos.y = (7 - pos.y);
        }

        return pos;
    }

    pub fn getSquareFromPos(self: *Render, pos: IVector2) u6 {
        if (pos.x >= 8 or pos.y >= 8) {
            return 0;
        }

        var x = (7 - pos.x);
        var y = pos.y;

        if (self.inverted) {
            x = pos.x;
            y = (7 - pos.y);
        }

        return @intCast(y * 8 + x);
    }

    pub fn drawBoard(self: *Render) void {
        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            for (0..8) |j| {
                const j_ = @as(i32, @intCast(j));
                const x = self.offset.x + i_ * self.tileSize;
                const y = self.offset.y + j_ * self.tileSize;

                var color = self.BLACK_TILE_COLOR;

                const square = @as(u6, @intCast(j_ * 8 + i_));
                if (self.isWhiteTile(square)) {
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
    }

    pub fn drawSquareNumbers(self: *Render) void {
        for (0..8) |i| {
            for (0..8) |j| {
                const square = @as(u6, @intCast(j * 8 + i));

                const pos = self.getPosFromSquare(square);

                const x = self.offset.x + pos.x * self.tileSize;
                const y = self.offset.y + pos.y * self.tileSize;

                var buf: [20]u8 = .{0} ** 20;
                _ = std.fmt.bufPrint(&buf, "{}", .{square}) catch std.debug.panic("Failed to format square number", .{});
                const squareNumber: [:0]const u8 = @ptrCast(&buf);

                const color = if (self.isWhiteTile(square)) rl.Color.white else rl.Color.black;
                rl.drawText(
                    squareNumber,
                    x + 5,
                    y + self.tileSize - 20 - 5,
                    20,
                    color,
                );
            }
        }
    }

    fn drawPossibleMove(self: *Render, move: *Move) void {
        const square = move.to;
        const pos = self.getPosFromSquare(square);

        const radius = @divTrunc(self.tileSize, 6);
        const padding = @divTrunc(self.tileSize - radius * 2, 2);

        const center = rl.Vector2.init(
            @as(f32, @floatFromInt(self.offset.x + pos.x * self.tileSize + padding + radius)),
            @as(f32, @floatFromInt(self.offset.y + pos.y * self.tileSize + padding + radius)),
        );

        if (move.getCode().isCapture()) {
            const size = @as(f32, @floatFromInt(self.tileSize));
            const rect = rl.Rectangle{
                .x = @as(f32, @floatFromInt(self.offset.x + pos.x * self.tileSize)) + 6.0,
                .y = @as(f32, @floatFromInt(self.offset.y + pos.y * self.tileSize)) + 6.0,
                .width = size - 12.0,
                .height = size - 12.0,
            };

            rl.drawRectangleRoundedLinesEx(rect, 16.0, 16, 6.0, self.POSSIBLE_MOVE_COLOR);
        } else {
            rl.drawCircleV(center, @as(f32, @floatFromInt(radius)), self.POSSIBLE_MOVE_COLOR);
        }
    }

    pub fn drawPossibleMoves(self: *Render, moves: *std.ArrayList(Move)) void {
        for (0..moves.items.len) |i| {
            var move: Move = moves.items[i];
            self.drawPossibleMove(&move);
        }
    }

    pub fn drawPossibleMovesFromSquare(self: *Render, moves: *std.ArrayList(Move), square: u6) void {
        for (0..moves.items.len) |i| {
            var move: Move = moves.items[i];
            if (move.from == square) {
                self.drawPossibleMove(&move);
            }
        }
    }

    pub fn highlightTile(self: *Render, square: u6) void {
        const pos = self.getPosFromSquare(square);

        const color = if (self.isWhiteTile(square)) self.ACTIVE_BLACK_TILE_COLOR else self.ACTIVE_WHITE_TILE_COLOR;

        const x = self.offset.x + pos.x * self.tileSize;
        const y = self.offset.y + pos.y * self.tileSize;

        rl.drawRectangle(
            x,
            y,
            self.tileSize,
            self.tileSize,
            color,
        );
    }

    pub fn highlightTileColor(self: *Render, square: u6, color: rl.Color) void {
        const pos = self.getPosFromSquare(square);
        const x = self.offset.x + pos.x * self.tileSize;
        const y = self.offset.y + pos.y * self.tileSize;

        rl.drawRectangle(
            x,
            y,
            self.tileSize,
            self.tileSize,
            color,
        );
    }

    fn drawPiece(self: *Render, pieceColor: PieceColor, pieceType: PieceType, square: u6) void {
        const pos = self.getPosFromSquare(square);

        const x = self.offset.x + pos.x * self.tileSize;
        const y = self.offset.y + pos.y * self.tileSize;

        const dest = rl.Rectangle.init(
            @as(f32, @floatFromInt(x)),
            @as(f32, @floatFromInt(y)),
            @as(f32, @floatFromInt(self.tileSize)),
            @as(f32, @floatFromInt(self.tileSize)),
        );

        const texture = self.textures[@as(usize, @intFromEnum(pieceColor))][@as(usize, @intFromEnum(pieceType))];

        const tWidth = @as(f32, @floatFromInt(texture.width));
        const tHeight = @as(f32, @floatFromInt(texture.height));
        const source = rl.Rectangle.init(0, 0, tWidth, tHeight);
        const origin = rl.Vector2.init(0, 0);

        rl.drawTexturePro(texture, source, dest, origin, 0.0, rl.Color.white);
    }

    pub fn drawPieces(self: *Render, board: *Board) void {
        for (0..PieceColorLength) |color| {
            for (0..PieceTypeLength) |piece| {
                const pieceColor: PieceColor = @enumFromInt(color);
                const pieceType: PieceType = @enumFromInt(piece);
                var bitboard = board.boards[color][piece];
                const one: u64 = 1;

                while (bitboard != 0) {
                    // const square = Render.countTrailingZeros(bitboard);
                    const square: u6 = @intCast(@ctz(bitboard));
                    self.drawPiece(pieceColor, pieceType, square);
                    bitboard &= ~(one << square);
                }
            }
        }
    }

    pub fn print(board: *Board) void {
        std.debug.print("Board:\n", .{});

        for (0..8) |rank| {
            for (0..8) |file| {
                const square = @as(u6, @intCast(rank * 8 + file));
                const piece = board.getPieceChar(square);
                if (piece != 0) {
                    std.debug.print("{c} ", .{piece});
                } else {
                    std.debug.print(". ", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn printBitboard(bitboard: Bitboard) void {
        for (0..8) |rank| {
            for (0..8) |file| {
                const square = @as(u6, @intCast(rank * 8 + file));
                const piece = if ((bitboard & (@as(u64, 1) << square)) != 0) "1" else "0";
                std.debug.print("{s} ", .{piece});
            }
            std.debug.print("\n", .{});
        }
    }
};
