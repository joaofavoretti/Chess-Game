// Responsabilities of the Board module:
// - Calculate the pieces possibleMoves;
// - Draw the board;

const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const IVector2 = @import("utils/ivector.zig").IVector2;
const IVector2Eq = @import("utils/ivector.zig").IVector2Eq;
const Move = @import("move.zig").Move;
const MoveType = @import("move.zig").MoveType;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

pub const Board = struct {
    WHITE_TILE_COLOR: rl.Color = rl.Color.init(232, 237, 249, 255),
    BLACK_TILE_COLOR: rl.Color = rl.Color.init(183, 192, 216, 255),
    ACTIVE_TILE_COLOR: rl.Color = rl.Color.init(123, 97, 255, 150),
    POSSIBLE_MOVE_COLOR: rl.Color = rl.Color.init(0, 0, 0, 50),

    pieces: std.AutoHashMap(IVector2, Piece),
    tileSize: i32,
    offsetX: i32,
    offsetY: i32,

    // Game Play logic
    isWhiteTurn: bool = true,
    selectedPiece: ?*Piece = null,
    possibleEnPassantPawn: ?*Piece = null,

    fn initPieces() !std.AutoHashMap(IVector2, Piece) {
        var pieces = std.AutoHashMap(IVector2, Piece).init(std.heap.page_allocator);

        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            try pieces.put(IVector2.init(i_, 6), Piece.init(IVector2.init(i_, 6), PieceColor.White, PieceType.Pawn));
            try pieces.put(IVector2.init(i_, 1), Piece.init(IVector2.init(i_, 1), PieceColor.Black, PieceType.Pawn));
        }

        return pieces;
    }

    pub fn init() Board {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);

        return Board{
            .pieces = initPieces() catch {
                std.debug.panic("Error initializing the AutoHashMap\n", .{});
            },
            .tileSize = tileSize,
            .offsetX = offsetX,
            .offsetY = offsetY,
        };
    }

    pub fn deinit(self: *Board) void {
        self.pieces.deinit();
    }

    fn drawPiece(self: *Board, piece: *Piece, pos: IVector2) void {
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
        if (!self.isMouseOverBoard()) {
            return IVector2.init(0, 0);
        }

        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return IVector2.init(
            @divTrunc(mousePos.x - self.offsetX, self.tileSize),
            @divTrunc(mousePos.y - self.offsetY, self.tileSize),
        );
    }

    fn getColorToMove(self: *Board) PieceColor {
        return switch (self.isWhiteTurn) {
            true => PieceColor.White,
            false => PieceColor.Black,
        };
    }

    fn movePiece(self: *Board, piece: *Piece, move: Move) void {
        if (move.getType() == MoveType.Promotion) {
            piece.pieceType = move.properties.Promotion.promotedTo;
        }

        const newPiece = Piece.init(move.to, piece.color, piece.pieceType);

        if (move.getType() == MoveType.EnPassant) {
            _ = self.pieces.remove(move.properties.EnPassant.capturedPiece.boardPos);
        }

        if (move.getType() == MoveType.Capture) {
            _ = self.pieces.remove(move.properties.Capture.capturedPiece.boardPos);
        }

        // Add the piece to the new position
        self.pieces.put(move.to, newPiece) catch {
            std.debug.panic("Error moving piece to correct square. Adding piece to AutoHashMap resulted in an error\n", .{});
        };

        // Store that the last move was a double pawn move in case of en passant
        if (move.getType() == MoveType.DoublePawn) {
            std.debug.print("Assigning possible en passant pawn\n", .{});
            self.possibleEnPassantPawn = self.pieces.getPtr(move.to);
        } else {
            self.possibleEnPassantPawn = null;
        }

        // Remove the piece from the old position
        _ = self.pieces.remove(move.from);

        self.selectedPiece = null;
    }

    fn verifyClickedPiece(self: *Board, deltaTime: f32) void {
        _ = deltaTime;

        if (self.isMouseOverBoard() and rl.isMouseButtonPressed(rl.MouseButton.left)) {
            const mousePos = self.getMouseBoardPosition();

            // Unselect the piece if it was clicked again
            if (self.selectedPiece) |piece| {
                if (IVector2Eq(piece.boardPos, mousePos)) {
                    self.selectedPiece = null;
                    return;
                }
            }

            // Verify if the piece was clicked
            var it = self.pieces.iterator();
            while (it.next()) |entry| {
                const piece = entry.value_ptr;

                if (self.getColorToMove() != piece.color) {
                    continue;
                }

                if (IVector2Eq(piece.boardPos, mousePos)) {
                    self.selectedPiece = piece;
                    return;
                }
            }

            // Verify if the piece was moved to a possible square
            if (self.selectedPiece) |piece| {
                const moves = self.getPossibleMoves(piece) catch std.debug.panic("Error getting possible moves\n", .{});
                for (moves.items) |move| {
                    if (IVector2Eq(move.to, mousePos)) {
                        self.movePiece(piece, move);
                        self.isWhiteTurn = !self.isWhiteTurn;
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

    fn getPawnPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        var moves = std.ArrayList(Move).init(std.heap.page_allocator);

        const forward: i32 = switch (piece.color) {
            PieceColor.White => -1,
            PieceColor.Black => 1,
        };

        // Verifying capture moves
        const forwardLeftPos = IVector2.init(piece.boardPos.x - 1, piece.boardPos.y + forward);
        const forwardLeftPosPiece = self.pieces.getPtr(forwardLeftPos);
        if (forwardLeftPosPiece) |attackedPiece| {
            if (attackedPiece.color != piece.color) {
                const move = Move.init(piece, piece.boardPos, forwardLeftPos, .{
                    .Capture = .{ .capturedPiece = attackedPiece },
                });
                try moves.append(move);
            }
        }

        const forwardRightPos = IVector2.init(piece.boardPos.x + 1, piece.boardPos.y + forward);
        const forwardRightPosPiece = self.pieces.getPtr(forwardRightPos);
        if (forwardRightPosPiece) |attackedPiece| {
            if (attackedPiece.color != piece.color) {
                const move = Move.init(piece, piece.boardPos, forwardRightPos, .{
                    .Capture = .{ .capturedPiece = attackedPiece },
                });
                try moves.append(move);
            }
        }

        // Verify en passant moves
        if (self.possibleEnPassantPawn) |enPassantPawn| {
            if (enPassantPawn.color != piece.color) {
                if (piece.boardPos.y == enPassantPawn.boardPos.y and
                    (piece.boardPos.x == enPassantPawn.boardPos.x - 1 or
                        piece.boardPos.x == enPassantPawn.boardPos.x + 1))
                {
                    const enPassantPos = IVector2.init(enPassantPawn.boardPos.x, enPassantPawn.boardPos.y + forward);
                    const move = Move.init(piece, piece.boardPos, enPassantPos, .{
                        .EnPassant = .{ .capturedPiece = enPassantPawn },
                    });
                    try moves.append(move);
                }
            }
        }

        // Verifying forward moves
        const forwardPos = IVector2.init(piece.boardPos.x, piece.boardPos.y + forward);
        if (self.pieces.get(forwardPos) == null) {
            if (forwardPos.y == 0 or forwardPos.y == 7) {
                const move = Move.init(piece, piece.boardPos, forwardPos, .{
                    .Promotion = .{ .promotedTo = PieceType.Queen },
                });
                try moves.append(move);
            } else {
                const move = Move.init(piece, piece.boardPos, forwardPos, .{ .Normal = .{} });
                try moves.append(move);
            }
        } else {
            return moves;
        }

        // Verifying double forward move
        if (piece.boardPos.y == 1 and piece.color == PieceColor.Black or
            piece.boardPos.y == 6 and piece.color == PieceColor.White)
        {
            const doubleForwardPos = IVector2.init(piece.boardPos.x, piece.boardPos.y + forward * 2);
            if (self.pieces.get(doubleForwardPos) == null) {
                const move = Move.init(piece, piece.boardPos, doubleForwardPos, .{ .DoublePawn = .{} });
                try moves.append(move);
            }
        }

        return moves;
    }

    fn getPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        const moves = switch (piece.pieceType) {
            PieceType.Pawn => try self.getPawnPossibleMoves(piece),
            else => std.ArrayList(Move).init(std.heap.page_allocator),
        };

        return moves;
    }

    fn drawBoard(self: *Board) void {
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
    }

    fn drawSelectedPieceTile(self: *Board) void {
        if (self.selectedPiece) |piece| {
            const x = self.offsetX + piece.boardPos.x * self.tileSize;
            const y = self.offsetY + piece.boardPos.y * self.tileSize;

            rl.drawRectangle(
                x,
                y,
                self.tileSize,
                self.tileSize,
                self.ACTIVE_TILE_COLOR,
            );
        }
    }

    fn drawPieces(self: *Board) void {
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr;
            const piece = entry.value_ptr;
            self.drawPiece(piece, pos.*);
        }
    }

    fn drawPossibleMoves(self: *Board) void {
        if (self.selectedPiece) |piece| {
            const moves = self.getPossibleMoves(piece) catch std.debug.panic("Error getting possible moves\n", .{});

            const radius = @divTrunc(self.tileSize, 8);
            const padding = @divTrunc(self.tileSize - radius * 2, 2);

            for (moves.items) |move| {
                const center = rl.Vector2.init(
                    @as(f32, @floatFromInt(self.offsetX + move.to.x * self.tileSize + padding + radius)),
                    @as(f32, @floatFromInt(self.offsetY + move.to.y * self.tileSize + padding + radius)),
                );

                if (move.getType() == MoveType.Capture) {
                    const size = @as(f32, @floatFromInt(self.tileSize));
                    const rect = rl.Rectangle{
                        .x = @as(f32, @floatFromInt(self.offsetX + move.to.x * self.tileSize)) + 6.0,
                        .y = @as(f32, @floatFromInt(self.offsetY + move.to.y * self.tileSize)) + 6.0,
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

    pub fn draw(self: *Board) void {
        self.drawBoard();
        self.drawSelectedPieceTile();
        self.drawPieces();
        self.drawPossibleMoves();
    }
};
