// Responsabilities of the Board module:
// - Calculate the pieces possibleMoves;
// - Draw the board;

const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const set = @import("ziglangSet");
const IVector2 = @import("utils/ivector.zig").IVector2;
const IVector2Eq = @import("utils/ivector.zig").IVector2Eq;
const IVector2Add = @import("utils/ivector.zig").IVector2Add;
const Move = @import("move.zig").Move;
const MoveType = @import("move.zig").MoveType;
const SoundSystem = @import("sound.zig").SoundSystem;
const SoundType = @import("sound.zig").SoundType;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

pub const Board = struct {
    // Futuristic color pallete
    // WHITE_TILE_COLOR: rl.Color = rl.Color.init(232, 237, 249, 255),
    // BLACK_TILE_COLOR: rl.Color = rl.Color.init(183, 192, 216, 255),
    // ACTIVE_TILE_COLOR: rl.Color = rl.Color.init(123, 97, 255, 150),
    // POSSIBLE_MOVE_COLOR: rl.Color = rl.Color.init(0, 0, 0, 50),

    // Default color pallete
    WHITE_TILE_COLOR: rl.Color = rl.Color.init(235, 236, 208, 255),
    BLACK_TILE_COLOR: rl.Color = rl.Color.init(115, 149, 82, 255),
    ACTIVE_WHITE_TILE_COLOR: rl.Color = rl.Color.init(245, 246, 130, 255),
    ACTIVE_BLACK_TILE_COLOR: rl.Color = rl.Color.init(185, 202, 67, 255),
    POSSIBLE_MOVE_COLOR: rl.Color = rl.Color.init(0, 0, 0, 30),

    soundSystem: ?SoundSystem = null,

    pieces: std.AutoHashMap(IVector2, Piece),
    tileSize: i32,
    offsetX: i32,
    offsetY: i32,

    // Game Play logic
    isWhiteTurn: bool = true,
    possibleEnPassantPawn: ?*Piece = null,
    unusedRooks: set.Set(*Piece),
    unusedKings: set.Set(*Piece),
    isGameOver: bool = false,
    selectedPiece: ?*Piece = null,
    cachedValidMoves: ?std.ArrayList(Move) = null,
    lastMove: ?Move = null,

    fn initPieces() !std.AutoHashMap(IVector2, Piece) {
        var pieces = std.AutoHashMap(IVector2, Piece).init(std.heap.page_allocator);

        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            try pieces.put(IVector2.init(i_, 6), Piece.init(IVector2.init(i_, 6), PieceColor.White, PieceType.Pawn));
            try pieces.put(IVector2.init(i_, 1), Piece.init(IVector2.init(i_, 1), PieceColor.Black, PieceType.Pawn));
        }

        try pieces.put(IVector2.init(0, 7), Piece.init(IVector2.init(0, 7), PieceColor.White, PieceType.Rook));
        try pieces.put(IVector2.init(7, 7), Piece.init(IVector2.init(7, 7), PieceColor.White, PieceType.Rook));
        try pieces.put(IVector2.init(0, 0), Piece.init(IVector2.init(0, 0), PieceColor.Black, PieceType.Rook));
        try pieces.put(IVector2.init(7, 0), Piece.init(IVector2.init(7, 0), PieceColor.Black, PieceType.Rook));

        try pieces.put(IVector2.init(1, 7), Piece.init(IVector2.init(1, 7), PieceColor.White, PieceType.Knight));
        try pieces.put(IVector2.init(6, 7), Piece.init(IVector2.init(6, 7), PieceColor.White, PieceType.Knight));
        try pieces.put(IVector2.init(1, 0), Piece.init(IVector2.init(1, 0), PieceColor.Black, PieceType.Knight));
        try pieces.put(IVector2.init(6, 0), Piece.init(IVector2.init(6, 0), PieceColor.Black, PieceType.Knight));

        try pieces.put(IVector2.init(2, 7), Piece.init(IVector2.init(2, 7), PieceColor.White, PieceType.Bishop));
        try pieces.put(IVector2.init(5, 7), Piece.init(IVector2.init(5, 7), PieceColor.White, PieceType.Bishop));
        try pieces.put(IVector2.init(2, 0), Piece.init(IVector2.init(2, 0), PieceColor.Black, PieceType.Bishop));
        try pieces.put(IVector2.init(5, 0), Piece.init(IVector2.init(5, 0), PieceColor.Black, PieceType.Bishop));

        try pieces.put(IVector2.init(3, 7), Piece.init(IVector2.init(3, 7), PieceColor.White, PieceType.Queen));
        try pieces.put(IVector2.init(3, 0), Piece.init(IVector2.init(3, 0), PieceColor.Black, PieceType.Queen));

        try pieces.put(IVector2.init(4, 7), Piece.init(IVector2.init(4, 7), PieceColor.White, PieceType.King));
        try pieces.put(IVector2.init(4, 0), Piece.init(IVector2.init(4, 0), PieceColor.Black, PieceType.King));

        return pieces;
    }

    fn initUnusedRooks(pieces: std.AutoHashMap(IVector2, Piece)) !set.Set(*Piece) {
        var unusedRooks = set.Set(*Piece).init(std.heap.page_allocator);

        var it = pieces.iterator();
        while (it.next()) |entry| {
            const piece = entry.value_ptr;
            if (piece.pieceType == PieceType.Rook) {
                _ = try unusedRooks.add(piece);
            }
        }

        return unusedRooks;
    }

    fn initUnusedKings(pieces: std.AutoHashMap(IVector2, Piece)) !set.Set(*Piece) {
        var unusedKings = set.Set(*Piece).init(std.heap.page_allocator);

        var it = pieces.iterator();
        while (it.next()) |entry| {
            const piece = entry.value_ptr;
            if (piece.pieceType == PieceType.King) {
                _ = try unusedKings.add(piece);
            }
        }

        return unusedKings;
    }

    pub fn init() Board {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);

        const pieces = initPieces() catch {
            std.debug.panic("Error initializing the AutoHashMap\n", .{});
        };

        const unusedRooks = initUnusedRooks(pieces) catch {
            std.debug.panic("Error initializing the Set\n", .{});
        };

        const unusedKings = initUnusedKings(pieces) catch {
            std.debug.panic("Error initializing the Set\n", .{});
        };

        const soundSystem = SoundSystem.init() catch {
            std.debug.panic("Error initializing the sound system\n", .{});
        };

        return Board{
            .pieces = pieces,
            .unusedRooks = unusedRooks,
            .unusedKings = unusedKings,
            .tileSize = tileSize,
            .offsetX = offsetX,
            .offsetY = offsetY,
            .soundSystem = soundSystem,
        };
    }

    pub fn deinit(self: *Board) void {
        self.pieces.deinit();
        self.unusedRooks.deinit();
        self.unusedKings.deinit();

        if (self.soundSystem) |*soundSystem| {
            soundSystem.deinit();
        }
    }

    pub fn playSound(self: *Board, soundType: SoundType) void {
        if (self.soundSystem) |*soundSystem| {
            soundSystem.playSound(soundType);
        }
    }

    fn drawPiece(self: *Board, piece: *Piece, pos: IVector2) void {
        if (pos.x >= 8 or pos.y >= 8) {
            return;
        }

        // const pieceSize = piece.getSize();

        // if (pieceSize.x > self.tileSize or pieceSize.y > self.tileSize) {
        //     std.debug.print("Piece size is bigger than tile size\n", .{});
        //     return;
        // }

        // const padding = @divTrunc(self.tileSize - pieceSize.x, 2);

        const dest = rl.Rectangle.init(
            @as(f32, @floatFromInt(self.offsetX + pos.x * self.tileSize)),
            @as(f32, @floatFromInt(self.offsetY + pos.y * self.tileSize)),
            @as(f32, @floatFromInt(self.tileSize)),
            @as(f32, @floatFromInt(self.tileSize)),
        );
        piece.draw(dest);
    }

    fn isWhiteTile(_: *Board, pos: IVector2) bool {
        return (@mod((pos.x + pos.y), 2) == 0);
    }

    fn isMouseOverBoard(self: *Board) bool {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return (mousePos.x >= self.offsetX and
            mousePos.x < self.offsetX + self.tileSize * 8 and
            mousePos.y >= self.offsetY and
            mousePos.y < self.offsetY + self.tileSize * 8);
    }

    fn isPositionOverBoard(_: *Board, pos: IVector2) bool {
        return (pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8);
    }

    fn isPositionBeingAttacked(self: *Board, pos: IVector2, colorAttacking: PieceColor) bool {
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const piece = entry.value_ptr;
            if (piece.color != colorAttacking) {
                continue;
            }

            const moves = self.getPossibleMoves(piece) catch std.debug.panic("Error getting possible moves\n", .{});
            for (moves.items) |move| {
                if (IVector2Eq(move.to, pos)) {
                    return true;
                }
            }
        }

        return false;
    }

    fn isKingInCheck(self: *Board, kingColor: PieceColor) bool {
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const piece = entry.value_ptr;
            if (piece.color != kingColor or piece.pieceType != PieceType.King) {
                continue;
            }

            const attackingColor = self.getOpositeColor(kingColor);
            return self.isPositionBeingAttacked(piece.boardPos, attackingColor);
        }

        return false;
    }

    fn isMoveValid(self: *Board, move: Move) bool {
        if (self.pieces.getPtr(move.from)) |piece| {
            var copy = self.getUndrawableCopy() catch std.debug.panic("Error getting a copy of the board\n", .{});
            if (copy.pieces.getPtr(move.from)) |copyPiece| {
                copy.movePiece(copyPiece, move);
            }
            const isNotInCheck = !copy.isKingInCheck(piece.color);
            copy.deinit();
            return isNotInCheck;
        }

        return false;
    }

    fn getUndrawableCopy(self: *Board) !Board {
        var pieces = std.AutoHashMap(IVector2, Piece).init(std.heap.page_allocator);
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const piece = entry.value_ptr;
            const newPiece = Piece.initUndrawable(piece.boardPos, piece.color, piece.pieceType);
            _ = try pieces.put(piece.boardPos, newPiece);
        }

        var unusedRooks = set.Set(*Piece).init(std.heap.page_allocator);
        var itRooks = self.unusedRooks.iterator();
        while (itRooks.next()) |entry| {
            if (pieces.getPtr(entry.*.boardPos)) |piece| {
                _ = try unusedRooks.add(piece);
            }
        }

        var unusedKings = set.Set(*Piece).init(std.heap.page_allocator);
        var itKings = self.unusedKings.iterator();
        while (itKings.next()) |entry| {
            if (pieces.getPtr(entry.*.boardPos)) |piece| {
                _ = try unusedKings.add(piece);
            }
        }

        var possibleEnPassantPawn: ?*Piece = null;
        if (self.possibleEnPassantPawn) |piece| {
            possibleEnPassantPawn = pieces.getPtr(piece.boardPos);
        }

        const copyUndrawable: Board = .{
            .pieces = pieces,
            .tileSize = self.tileSize,
            .offsetX = self.offsetX,
            .offsetY = self.offsetY,
            .isWhiteTurn = self.isWhiteTurn,
            .selectedPiece = null,
            .possibleEnPassantPawn = possibleEnPassantPawn,
            .unusedRooks = unusedRooks,
            .unusedKings = unusedKings,
        };

        return copyUndrawable;
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

    fn getOpositeColor(_: *Board, color: PieceColor) PieceColor {
        return switch (color) {
            PieceColor.White => PieceColor.Black,
            PieceColor.Black => PieceColor.White,
        };
    }

    fn movePiece(self: *Board, piece: *Piece, move: Move) void {
        var sound = SoundType.MoveSelf;
        if (!self.isWhiteTurn) {
            sound = SoundType.MoveOpponent;
        }

        var newPiece = piece.getCopy();
        newPiece.boardPos = move.to;

        if (move.getType() == MoveType.Promotion) {
            newPiece.setType(move.properties.Promotion.promotedTo);
            sound = SoundType.Promote;
        }

        if (move.getType() == MoveType.EnPassant) {
            _ = self.pieces.remove(move.properties.EnPassant.capturedPiece.boardPos);
            sound = SoundType.Capture;
        }

        if (move.getType() == MoveType.Capture) {
            _ = self.pieces.remove(move.properties.Capture.capturedPiece.boardPos);
            sound = SoundType.Capture;
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

        // Store the rook that was moved in case of castling
        if (self.unusedRooks.contains(piece)) {
            _ = self.unusedRooks.remove(piece);
        }

        // Store the king that was moved in case of castling
        if (self.unusedKings.contains(piece)) {
            _ = self.unusedKings.remove(piece);
        }

        // Remove the piece from the old position
        _ = self.pieces.remove(move.from);

        if (move.getType() == MoveType.Castle) {
            var newRook = move.properties.Castle.rook.getCopy();
            newRook.boardPos = move.properties.Castle.rookTo;

            _ = self.pieces.remove(move.properties.Castle.rookFrom);
            self.pieces.put(move.properties.Castle.rookTo, newRook) catch {
                std.debug.panic("Error moving rook to correct square. Adding piece to AutoHashMap resulted in an error\n", .{});
            };
            sound = SoundType.Castle;
        }

        if (self.isKingInCheck(self.getColorToMove())) {
            sound = SoundType.Check;
        }

        self.playSound(sound);

        self.lastMove = move;
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
                    self.cachedValidMoves = self.getValidMoves(piece) catch std.debug.panic("Error getting possible moves\n", .{});
                    return;
                }
            }

            // Verify if the piece was moved to a possible square
            if (self.selectedPiece) |piece| {
                if (self.cachedValidMoves) |moves| {
                    for (moves.items) |move| {
                        if (IVector2Eq(move.to, mousePos)) {
                            self.movePiece(piece, move);
                            self.isWhiteTurn = !self.isWhiteTurn;
                            self.isGameOver = self.isKingInCheck(self.getColorToMove()) and !self.areThereValidMoves();

                            if (self.isGameOver) {
                                self.playSound(SoundType.GameEnd);
                            }

                            return;
                        }
                    }
                }
            }

            // If clickeed outside the piece, unselect it
            self.selectedPiece = null;
        }
    }

    fn areThereValidMoves(self: *Board) bool {
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const piece = entry.value_ptr;
            if (piece.color != self.getColorToMove()) {
                continue;
            }

            const moves = self.getValidMoves(piece) catch std.debug.panic("Error getting possible moves\n", .{});
            if (moves.items.len > 0) {
                return true;
            }
            moves.deinit();
        }

        std.debug.print("Done checking possible moves\n", .{});

        return false;
    }

    pub fn update(self: *Board, deltaTime: f32) void {
        if (self.isGameOver) {
            return;
        }

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

    fn getRookPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        var moves = std.ArrayList(Move).init(std.heap.page_allocator);

        const directions = [_]IVector2{
            IVector2.init(1, 0),
            IVector2.init(-1, 0),
            IVector2.init(0, 1),
            IVector2.init(0, -1),
        };

        for (directions) |dir| {
            var pos = IVector2Add(piece.boardPos, dir);
            while (self.isPositionOverBoard(pos)) {
                const pieceAtPos = self.pieces.getPtr(pos);
                if (pieceAtPos) |attackedPiece| {
                    if (attackedPiece.color != piece.color) {
                        const move = Move.init(piece, piece.boardPos, pos, .{
                            .Capture = .{ .capturedPiece = attackedPiece },
                        });
                        try moves.append(move);
                    }
                    break;
                } else {
                    const move = Move.init(piece, piece.boardPos, pos, .{ .Normal = .{} });
                    try moves.append(move);
                }

                pos = IVector2Add(pos, dir);
            }
        }

        return moves;
    }

    fn getKnightPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        var moves = std.ArrayList(Move).init(std.heap.page_allocator);

        const directions = [_]IVector2{
            IVector2.init(1, 2),
            IVector2.init(2, 1),
            IVector2.init(2, -1),
            IVector2.init(1, -2),
            IVector2.init(-1, -2),
            IVector2.init(-2, -1),
            IVector2.init(-2, 1),
            IVector2.init(-1, 2),
        };

        for (directions) |dir| {
            const pos = IVector2Add(piece.boardPos, dir);

            if (!self.isPositionOverBoard(pos)) {
                continue;
            }

            const pieceAtPos = self.pieces.getPtr(pos);
            if (pieceAtPos) |attackedPiece| {
                if (attackedPiece.color != piece.color) {
                    const move = Move.init(piece, piece.boardPos, pos, .{
                        .Capture = .{ .capturedPiece = attackedPiece },
                    });
                    try moves.append(move);
                }
            } else {
                const move = Move.init(piece, piece.boardPos, pos, .{ .Normal = .{} });
                try moves.append(move);
            }
        }

        return moves;
    }

    fn getBishopPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        var moves = std.ArrayList(Move).init(std.heap.page_allocator);

        const directions = [_]IVector2{
            IVector2.init(1, 1),
            IVector2.init(1, -1),
            IVector2.init(-1, -1),
            IVector2.init(-1, 1),
        };

        for (directions) |dir| {
            var pos = IVector2Add(piece.boardPos, dir);
            while (self.isPositionOverBoard(pos)) {
                const pieceAtPos = self.pieces.getPtr(pos);
                if (pieceAtPos) |attackedPiece| {
                    if (attackedPiece.color != piece.color) {
                        const move = Move.init(piece, piece.boardPos, pos, .{
                            .Capture = .{ .capturedPiece = attackedPiece },
                        });
                        try moves.append(move);
                    }
                    break;
                } else {
                    const move = Move.init(piece, piece.boardPos, pos, .{ .Normal = .{} });
                    try moves.append(move);
                }

                pos = IVector2Add(pos, dir);
            }
        }

        return moves;
    }

    fn getQueenPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        var moves = std.ArrayList(Move).init(std.heap.page_allocator);

        const directions = [_]IVector2{
            IVector2.init(1, 0),
            IVector2.init(-1, 0),
            IVector2.init(0, 1),
            IVector2.init(0, -1),
            IVector2.init(1, 1),
            IVector2.init(1, -1),
            IVector2.init(-1, -1),
            IVector2.init(-1, 1),
        };

        for (directions) |dir| {
            var pos = IVector2Add(piece.boardPos, dir);
            while (self.isPositionOverBoard(pos)) {
                const pieceAtPos = self.pieces.getPtr(pos);
                if (pieceAtPos) |attackedPiece| {
                    if (attackedPiece.color != piece.color) {
                        const move = Move.init(piece, piece.boardPos, pos, .{
                            .Capture = .{ .capturedPiece = attackedPiece },
                        });
                        try moves.append(move);
                    }
                    break;
                } else {
                    const move = Move.init(piece, piece.boardPos, pos, .{ .Normal = .{} });
                    try moves.append(move);
                }

                pos = IVector2Add(pos, dir);
            }
        }

        return moves;
    }

    fn getKingPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        var moves = std.ArrayList(Move).init(std.heap.page_allocator);

        const directions = [_]IVector2{
            IVector2.init(1, 0),
            IVector2.init(-1, 0),
            IVector2.init(0, 1),
            IVector2.init(0, -1),
            IVector2.init(1, 1),
            IVector2.init(1, -1),
            IVector2.init(-1, -1),
            IVector2.init(-1, 1),
        };

        // Normal and Capture moves
        for (directions) |dir| {
            const pos = IVector2Add(piece.boardPos, dir);

            if (!self.isPositionOverBoard(pos)) {
                continue;
            }

            const pieceAtPos = self.pieces.getPtr(pos);
            if (pieceAtPos) |attackedPiece| {
                if (attackedPiece.color != piece.color) {
                    const move = Move.init(piece, piece.boardPos, pos, .{
                        .Capture = .{ .capturedPiece = attackedPiece },
                    });
                    try moves.append(move);
                }
            } else {
                const move = Move.init(piece, piece.boardPos, pos, .{ .Normal = .{} });
                try moves.append(move);
            }
        }

        // Castling moves
        if (self.unusedKings.contains(piece)) {
            const leftRook = self.pieces.getPtr(IVector2.init(0, piece.boardPos.y));
            if (leftRook) |rook| {
                if (self.unusedRooks.contains(rook) and
                    self.pieces.get(IVector2.init(1, piece.boardPos.y)) == null and
                    self.pieces.get(IVector2.init(2, piece.boardPos.y)) == null and
                    self.pieces.get(IVector2.init(3, piece.boardPos.y)) == null)
                {
                    const move = Move.init(piece, piece.boardPos, IVector2.init(2, piece.boardPos.y), .{
                        .Castle = .{
                            .rook = rook,
                            .rookFrom = IVector2.init(0, piece.boardPos.y),
                            .rookTo = IVector2.init(3, piece.boardPos.y),
                        },
                    });
                    try moves.append(move);
                }
            }

            const rightRook = self.pieces.getPtr(IVector2.init(7, piece.boardPos.y));
            if (rightRook) |rook| {
                if (self.unusedRooks.contains(rook) and
                    self.pieces.get(IVector2.init(5, piece.boardPos.y)) == null and
                    self.pieces.get(IVector2.init(6, piece.boardPos.y)) == null)
                {
                    const move = Move.init(piece, piece.boardPos, IVector2.init(6, piece.boardPos.y), .{
                        .Castle = .{
                            .rook = rook,
                            .rookFrom = IVector2.init(7, piece.boardPos.y),
                            .rookTo = IVector2.init(5, piece.boardPos.y),
                        },
                    });
                    try moves.append(move);
                }
            }
        }

        return moves;
    }

    fn getPossibleMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        const moves = switch (piece.pieceType) {
            PieceType.Pawn => try self.getPawnPossibleMoves(piece),
            PieceType.Rook => try self.getRookPossibleMoves(piece),
            PieceType.Knight => try self.getKnightPossibleMoves(piece),
            PieceType.Bishop => try self.getBishopPossibleMoves(piece),
            PieceType.Queen => try self.getQueenPossibleMoves(piece),
            PieceType.King => try self.getKingPossibleMoves(piece),
        };

        return moves;
    }

    fn getValidMoves(self: *Board, piece: *Piece) !std.ArrayList(Move) {
        const moves = try self.getPossibleMoves(piece);

        var validMoves = std.ArrayList(Move).init(std.heap.page_allocator);
        for (moves.items) |move| {
            if (self.isMoveValid(move)) {
                _ = validMoves.append(move) catch {
                    std.debug.panic("Error appending move to movesThatWillPreventCheck\n", .{});
                };
            }
        }

        moves.deinit();

        return validMoves;
    }

    fn drawTile(self: *Board, pos: IVector2, active: bool) void {
        const x = self.offsetX + pos.x * self.tileSize;
        const y = self.offsetY + pos.y * self.tileSize;

        var color = self.BLACK_TILE_COLOR;

        if (self.isWhiteTile(pos)) {
            color = self.WHITE_TILE_COLOR;
        }

        if (active) {
            if (self.isWhiteTile(pos)) {
                color = self.ACTIVE_WHITE_TILE_COLOR;
            } else {
                color = self.ACTIVE_BLACK_TILE_COLOR;
            }
        }

        rl.drawRectangle(
            x,
            y,
            self.tileSize,
            self.tileSize,
            color,
        );
    }

    fn drawBoard(self: *Board) void {
        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            for (0..8) |j| {
                const j_ = @as(i32, @intCast(j));
                const x = self.offsetX + i_ * self.tileSize;
                const y = self.offsetY + j_ * self.tileSize;

                var color = self.BLACK_TILE_COLOR;

                if (self.isWhiteTile(IVector2.init(i_, j_))) {
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

        if (self.lastMove) |move| {
            self.drawTile(move.from, true);
            self.drawTile(move.to, true);
        }
    }

    fn drawSelectedPieceTile(self: *Board) void {
        if (self.selectedPiece) |piece| {
            const x = self.offsetX + piece.boardPos.x * self.tileSize;
            const y = self.offsetY + piece.boardPos.y * self.tileSize;

            var color = self.ACTIVE_BLACK_TILE_COLOR;

            if (self.isWhiteTile(piece.boardPos)) {
                color = self.ACTIVE_WHITE_TILE_COLOR;
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

    fn drawPieces(self: *Board) void {
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr;
            const piece = entry.value_ptr;
            self.drawPiece(piece, pos.*);

            // Draw a little circle around the king to show it is in check
            // if (piece.pieceType == PieceType.King) {
            //     if (self.isKingInCheck(piece.color)) {
            //         const size = @as(f32, @floatFromInt(self.tileSize));
            //         const rect = rl.Rectangle{
            //             .x = @as(f32, @floatFromInt(self.offsetX + piece.boardPos.x * self.tileSize)) + 6.0,
            //             .y = @as(f32, @floatFromInt(self.offsetY + piece.boardPos.y * self.tileSize)) + 6.0,
            //             .width = size - 12.0,
            //             .height = size - 12.0,
            //         };
            //
            //         rl.drawRectangleRoundedLinesEx(rect, 16.0, 16, 6.0, rl.Color.red);
            //     }
            // }
        }
    }

    fn drawPossibleMoves(self: *Board) void {
        if (self.selectedPiece != null) {
            if (self.cachedValidMoves) |moves| {
                const radius = @divTrunc(self.tileSize, 6);
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
    }

    pub fn draw(self: *Board) void {
        self.drawBoard();
        self.drawSelectedPieceTile();
        self.drawPieces();
        self.drawPossibleMoves();

        if (self.isGameOver) {
            const text = switch (self.getColorToMove()) {
                PieceColor.White => "Black wins!",
                PieceColor.Black => "White wins!",
            };

            const textSize = rl.measureText(text, 20);
            const x = @divTrunc((rl.getScreenWidth() - textSize), 2);
            const y = @divTrunc(rl.getScreenHeight(), 2);

            rl.drawText(text, x, y, 20, rl.Color.red);
        }
    }
};
