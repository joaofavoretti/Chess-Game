const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const utils = @import("utils.zig");
const IVector2 = utils.IVector2;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

pub const Board = struct {
    pieces: std.AutoHashMap(IVector2, Piece),
    selectedPiece: ?*Piece = null,
    tileSize: i32,
    offsetX: i32,
    offsetY: i32,

    WHITE_TILE_COLOR: rl.Color = rl.Color.init(232, 237, 249, 255),
    BLACK_TILE_COLOR: rl.Color = rl.Color.init(183, 192, 216, 255),
    ACTIVE_TILE_COLOR: rl.Color = rl.Color.init(123, 97, 255, 150),
    POSSIBLE_MOVE_COLOR: rl.Color = rl.Color.init(0, 0, 0, 50),

    fn initPieces() std.AutoHashMap(IVector2, Piece) {
        var pieces = std.AutoHashMap(IVector2, Piece).init(std.heap.page_allocator);

        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            pieces.put(IVector2.init(i_, 6), Piece.init(IVector2.init(i_, 6), PieceColor.White, PieceType.Pawn)) catch unreachable;
            pieces.put(IVector2.init(i_, 1), Piece.init(IVector2.init(i_, 1), PieceColor.Black, PieceType.Pawn)) catch unreachable;
        }

        // pieces.put(IVector2.init(0, 7), Piece.init(IVector2.init(0, 7), PieceColor.White, PieceType.Rook)) catch unreachable;
        // pieces.put(IVector2.init(7, 7), Piece.init(IVector2.init(7, 7), PieceColor.White, PieceType.Rook)) catch unreachable;
        // pieces.put(IVector2.init(0, 0), Piece.init(IVector2.init(0, 0), PieceColor.Black, PieceType.Rook)) catch unreachable;
        // pieces.put(IVector2.init(7, 0), Piece.init(IVector2.init(7, 0), PieceColor.Black, PieceType.Rook)) catch unreachable;
        // pieces.put(IVector2.init(1, 7), Piece.init(IVector2.init(1, 7), PieceColor.White, PieceType.Knight)) catch unreachable;
        // pieces.put(IVector2.init(6, 7), Piece.init(IVector2.init(6, 7), PieceColor.White, PieceType.Knight)) catch unreachable;
        // pieces.put(IVector2.init(1, 0), Piece.init(IVector2.init(1, 0), PieceColor.Black, PieceType.Knight)) catch unreachable;
        // pieces.put(IVector2.init(6, 0), Piece.init(IVector2.init(6, 0), PieceColor.Black, PieceType.Knight)) catch unreachable;
        // pieces.put(IVector2.init(2, 7), Piece.init(IVector2.init(2, 7), PieceColor.White, PieceType.Bishop)) catch unreachable;
        // pieces.put(IVector2.init(5, 7), Piece.init(IVector2.init(5, 7), PieceColor.White, PieceType.Bishop)) catch unreachable;
        // pieces.put(IVector2.init(2, 0), Piece.init(IVector2.init(2, 0), PieceColor.Black, PieceType.Bishop)) catch unreachable;
        // pieces.put(IVector2.init(5, 0), Piece.init(IVector2.init(5, 0), PieceColor.Black, PieceType.Bishop)) catch unreachable;
        // pieces.put(IVector2.init(3, 7), Piece.init(IVector2.init(3, 7), PieceColor.White, PieceType.Queen)) catch unreachable;
        // pieces.put(IVector2.init(3, 0), Piece.init(IVector2.init(3, 0), PieceColor.Black, PieceType.Queen)) catch unreachable;
        // pieces.put(IVector2.init(4, 7), Piece.init(IVector2.init(4, 7), PieceColor.White, PieceType.King)) catch unreachable;
        // pieces.put(IVector2.init(4, 0), Piece.init(IVector2.init(4, 0), PieceColor.Black, PieceType.King)) catch unreachable;

        return pieces;
    }

    pub fn init() Board {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);

        return Board{
            .pieces = initPieces(),
            .tileSize = tileSize,
            .offsetX = offsetX,
            .offsetY = offsetY,
        };
    }

    pub fn deinit(self: *Board) void {
        self.pieces.deinit();
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

    fn isMouseOverBoard(self: *Board) bool {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return (mousePos.x >= self.offsetX and
            mousePos.x < self.offsetX + self.tileSize * 8 and
            mousePos.y >= self.offsetY and
            mousePos.y < self.offsetY + self.tileSize * 8);
    }

    fn getMouseBoardPosition(self: *Board) IVector2 {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return IVector2.init(
            @divTrunc(mousePos.x - self.offsetX, self.tileSize),
            @divTrunc(mousePos.y - self.offsetY, self.tileSize),
        );
    }

    fn verifyClickedPiece(self: *Board, deltaTime: f32) void {
        _ = deltaTime;

        if (self.isMouseOverBoard() and rl.isMouseButtonPressed(rl.MouseButton.left)) {
            const mousePos = self.getMouseBoardPosition();

            // Unselect the piece if it was clicked again
            if (self.selectedPiece) |piece| {
                if (utils.iVector2Eq(piece.pos, mousePos)) {
                    self.selectedPiece = null;
                    return;
                }
            }

            // Verify if the piece was clicked
            var it = self.pieces.iterator();
            while (it.next()) |entry| {
                const piece = entry.value_ptr;

                if (utils.iVector2Eq(piece.pos, mousePos)) {
                    self.selectedPiece = piece;
                    return;
                }
            }

            // Verify if the piece was moved to a possible square
            if (self.selectedPiece) |piece| {
                const moves = self.getPossibleMoves(piece);
                for (moves.items) |move| {
                    if (utils.iVector2Eq(move, mousePos)) {
                        const newPiece = Piece.init(move, piece.color, piece.pieceType);

                        if (self.pieces.remove(piece.pos)) {
                            std.debug.print("Removed piece from the AutoHashMap\n", .{});
                        } else {
                            std.debug.print("Piece was not removed from the AutoHashMap\n", .{});
                        }

                        self.pieces.put(move, newPiece) catch {
                            std.debug.panic("Error moving piece to correct square. Adding piece to AutoHashMap resulted in an error\n", .{});
                        };

                        self.selectedPiece = null;
                        return;
                    }
                }
            }

            // If clickeed outside the piece, unselect it
            self.selectedPiece = null;
        }
    }

    pub fn update(self: *Board, deltaTime: f32) void {
        verifyClickedPiece(self, deltaTime);
    }

    pub fn getPawnPossibleMoves(self: *Board, piece: *Piece) std.ArrayList(IVector2) {
        var moves = std.ArrayList(IVector2).init(std.heap.page_allocator);

        const forward: i32 = switch (piece.color) {
            PieceColor.White => -1,
            PieceColor.Black => 1,
        };

        // Verifying capture moves
        const forwardLeftPos = IVector2.init(piece.pos.x - 1, piece.pos.y + forward);
        if (self.pieces.get(forwardLeftPos) != null) {
            moves.append(forwardLeftPos) catch unreachable;
        }

        const forwardRightPos = IVector2.init(piece.pos.x + 1, piece.pos.y + forward);
        if (self.pieces.get(forwardRightPos) != null) {
            moves.append(forwardRightPos) catch unreachable;
        }

        // Verifying forward moves
        const forwardPos = IVector2.init(piece.pos.x, piece.pos.y + forward);
        if (self.pieces.get(forwardPos) == null) {
            moves.append(forwardPos) catch unreachable;
        } else {
            return moves;
        }

        // Verifying double forward move
        if (piece.pos.y == 1 and piece.color == PieceColor.Black or
            piece.pos.y == 6 and piece.color == PieceColor.White)
        {
            const doubleForwardPos = IVector2.init(piece.pos.x, piece.pos.y + forward * 2);
            if (self.pieces.get(doubleForwardPos) == null) {
                moves.append(doubleForwardPos) catch unreachable;
            }
        }

        return moves;
    }

    pub fn getPossibleMoves(self: *Board, piece: *Piece) std.ArrayList(IVector2) {
        const moves = switch (piece.pieceType) {
            PieceType.Pawn => self.getPawnPossibleMoves(piece),
            // PieceType.Rook => self.getRookPossibleMoves(piece, moves),
            // PieceType.Knight => self.getKnightPossibleMoves(piece, moves),
            // PieceType.Bishop => self.getBishopPossibleMoves(piece, moves),
            // PieceType.Queen => self.getQueenPossibleMoves(piece, moves),
            // PieceType.King => self.getKingPossibleMoves(piece, moves),
            else => std.ArrayList(IVector2).init(std.heap.page_allocator),
        };

        return moves;
    }

    pub fn draw(self: *Board) void {
        // Draw the board colors
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

        // Draw the selected piece board color
        if (self.selectedPiece) |piece| {
            const x = self.offsetX + piece.pos.x * self.tileSize;
            const y = self.offsetY + piece.pos.y * self.tileSize;

            rl.drawRectangle(
                x,
                y,
                self.tileSize,
                self.tileSize,
                self.ACTIVE_TILE_COLOR,
            );
        }

        // Draw the pieces in the HashMap
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr;
            const piece = entry.value_ptr;
            self.drawPiece(piece, pos.*);
        }

        // Draw the possible moves dots from the selected piece
        if (self.selectedPiece) |piece| {
            const moves = self.getPossibleMoves(piece);

            const radius = @divTrunc(self.tileSize, 8);
            const padding = @divTrunc(self.tileSize - radius * 2, 2);

            for (moves.items) |move| {
                const center = rl.Vector2.init(
                    @as(f32, @floatFromInt(self.offsetX + move.x * self.tileSize + padding + radius)),
                    @as(f32, @floatFromInt(self.offsetY + move.y * self.tileSize + padding + radius)),
                );

                if (self.pieces.get(move) != null) {
                    // Draw an outer circle when there is the possibility of capturing a piece
                    const size = @as(f32, @floatFromInt(self.tileSize));
                    const rect = rl.Rectangle{
                        .x = @as(f32, @floatFromInt(self.offsetX + move.x * self.tileSize)) + 6.0,
                        .y = @as(f32, @floatFromInt(self.offsetY + move.y * self.tileSize)) + 6.0,
                        .width = size - 12.0,
                        .height = size - 12.0,
                    };

                    rl.drawRectangleRoundedLinesEx(rect, 16.0, 16, 6.0, self.POSSIBLE_MOVE_COLOR);
                } else {
                    rl.drawCircleV(center, @as(f32, @floatFromInt(radius)), self.POSSIBLE_MOVE_COLOR);
                }
            }
        }
    }
};
