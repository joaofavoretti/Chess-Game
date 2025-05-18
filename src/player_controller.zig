const std = @import("std");
const rl = @import("raylib");
const iv = @import("ivector.zig");
const p = @import("piece.zig");
const b = @import("board.zig");
const m = @import("move.zig");
const r = @import("render.zig");
const ss = @import("selected_square.zig");
const pc = @import("player_controller.zig");
const ec = @import("engine_controller.zig");
const gs = @import("game_state.zig");
const mg = @import("move_gen.zig");

const IVector2 = iv.IVector2;
const SelectedSquare = ss.SelectedSquare;
const Move = m.Move;
const Render = r.Render;
const Board = b.Board;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const MoveCode = m.MoveCode;
const MoveGen = mg.MoveGen;

pub const PlayerController = struct {
    tileSize: i32,
    offset: IVector2,
    selectedSquare: SelectedSquare = SelectedSquare.init(),
    pseudoLegalMoves: std.BoundedArray(Move, 64) = .{},

    pub fn init(baseRender: *Render) PlayerController {
        return PlayerController{
            .tileSize = baseRender.tileSize,
            .offset = baseRender.offset,
        };
    }

    fn updatePawnMoves(self: *PlayerController, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();
        var direction: i32 = if (color == PieceColor.White) 1 else -1;

        if (render.inverted) direction *= -1;

        // Capture diagonally
        for (0..2) |i| {
            const i_ = @as(i32, @intCast(i));
            const targetPos = iv.IVector2Add(pos, IVector2.init(i_ * 2 - 1, direction));
            if (!render.isPosValid(targetPos)) {
                continue;
            }
            const targetSquare = render.getSquareFromPos(targetPos);
            var targetPiece = board.getPiece(targetSquare);

            // Regular diagonal capture
            if (targetPiece.valid and targetPiece.getColor() != color) {
                const finalFile: i32 = if (color == PieceColor.White) 7 else 0;
                const isFinalPosition = (targetSquare / 8) == finalFile;
                if (isFinalPosition) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QueenPromotionCapture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .Capture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                }
            }

            // En passant capture
            if (board.enPassantTarget) |enPassantTarget| {
                if (targetSquare == enPassantTarget) {
                    if (board.lastMoves.getLastOrNull()) |lastMove| {
                        var lastMovePiece = board.getPiece(lastMove.to);
                        if (lastMovePiece.valid and lastMovePiece.getColor() != color and lastMove.getCode() == MoveCode.DoublePawnPush) {
                            self.pseudoLegalMoves.append(Move.init(
                                self.selectedSquare.square,
                                targetSquare,
                                board,
                                .{ .EnPassant = .{ .capturedPiece = lastMovePiece } },
                            )) catch std.debug.panic("Failed to append move", .{});
                        }
                    }
                }
            }
        }

        // Move forward
        const forwardPos = iv.IVector2Add(pos, IVector2.init(0, direction));
        if (!render.isPosValid(forwardPos)) {
            return;
        }
        const forwardSquare = render.getSquareFromPos(forwardPos);
        const forwardPiece = board.getPiece(forwardSquare);
        if (!forwardPiece.valid) {
            const finalFile: i32 = if (color == PieceColor.White) 7 else 0;
            const isFinalPosition = (forwardSquare / 8) == finalFile;
            if (isFinalPosition) {
                self.pseudoLegalMoves.append(Move.init(
                    self.selectedSquare.square,
                    forwardSquare,
                    board,
                    .{ .QueenPromotion = .{} },
                )) catch std.debug.panic("Failed to append move", .{});
                return;
            } else {
                self.pseudoLegalMoves.append(Move.init(
                    self.selectedSquare.square,
                    forwardSquare,
                    board,
                    .{ .QuietMove = .{} },
                )) catch std.debug.panic("Failed to append move", .{});
            }

            // Double pawn push
            const doubleForwardPos = iv.IVector2Add(forwardPos, IVector2.init(0, direction));
            if (!render.isPosValid(doubleForwardPos)) {
                return;
            }
            const doubleForwardSquare = render.getSquareFromPos(doubleForwardPos);
            const doubleForwardPiece = board.getPiece(doubleForwardSquare);
            const initialFile: i32 = if (color == PieceColor.White) 1 else 6;
            const isInitialPosition = (self.selectedSquare.square / 8) == initialFile;
            if (!doubleForwardPiece.valid and isInitialPosition) {
                self.pseudoLegalMoves.append(Move.init(
                    self.selectedSquare.square,
                    doubleForwardSquare,
                    board,
                    .{ .DoublePawnPush = .{} },
                )) catch std.debug.panic("Failed to append move", .{});
            }
        }
    }

    fn updateKnightMoves(self: *PlayerController, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Knight moves
        const knightMoves = [8]IVector2{
            IVector2.init(1, 2),
            IVector2.init(2, 1),
            IVector2.init(2, -1),
            IVector2.init(1, -2),
            IVector2.init(-1, -2),
            IVector2.init(-2, -1),
            IVector2.init(-2, 1),
            IVector2.init(-1, 2),
        };

        for (0..8) |i| {
            const move = knightMoves[i];
            const targetPos = iv.IVector2Add(pos, move);

            if (render.isPosValid(targetPos)) {
                const targetSquare = render.getSquareFromPos(targetPos);
                var targetPiece = board.getPiece(targetSquare);
                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                }

                if (targetPiece.valid and targetPiece.getColor() != color) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .Capture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                }
            }
        }
    }

    fn updateBishopMoves(self: *PlayerController, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Directions for bishop movement: top-right, top-left, bottom-right, bottom-left
        const directions = [4]IVector2{
            IVector2.init(1, 1),
            IVector2.init(-1, 1),
            IVector2.init(1, -1),
            IVector2.init(-1, -1),
        };

        for (directions) |direction| {
            var currentPos = pos;

            while (true) {
                currentPos = iv.IVector2Add(currentPos, direction);

                if (!render.isPosValid(currentPos)) {
                    break;
                }

                const targetSquare = render.getSquareFromPos(currentPos);
                var targetPiece = board.getPiece(targetSquare);

                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else {
                    if (targetPiece.getColor() != color) {
                        self.pseudoLegalMoves.append(Move.init(
                            self.selectedSquare.square,
                            targetSquare,
                            board,
                            .{ .Capture = .{ .capturedPiece = targetPiece } },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                    break; // Stop moving in this direction after encountering a piece
                }
            }
        }
    }

    fn updateRookMoves(self: *PlayerController, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Directions for rook movement: up, down, left, right
        const directions = [4]IVector2{
            IVector2.init(0, 1), // Up
            IVector2.init(0, -1), // Down
            IVector2.init(1, 0), // Right
            IVector2.init(-1, 0), // Left
        };

        for (directions) |direction| {
            var currentPos = pos;

            while (true) {
                currentPos = iv.IVector2Add(currentPos, direction);

                if (!render.isPosValid(currentPos)) {
                    break;
                }

                const targetSquare = render.getSquareFromPos(currentPos);
                var targetPiece = board.getPiece(targetSquare);

                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else {
                    if (targetPiece.getColor() != color) {
                        self.pseudoLegalMoves.append(Move.init(
                            self.selectedSquare.square,
                            targetSquare,
                            board,
                            .{ .Capture = .{ .capturedPiece = targetPiece } },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                    break; // Stop moving in this direction after encountering a piece
                }
            }
        }
    }

    fn updateKingMoves(self: *PlayerController, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Direction vectors for king moves.
        const kingMoves = [8]IVector2{
            IVector2.init(1, 0),
            IVector2.init(1, 1),
            IVector2.init(0, 1),
            IVector2.init(-1, 1),
            IVector2.init(-1, 0),
            IVector2.init(-1, -1),
            IVector2.init(0, -1),
            IVector2.init(1, -1),
        };

        // Regular moves
        for (kingMoves) |delta| {
            const targetPos = iv.IVector2Add(pos, delta);
            if (render.isPosValid(targetPos)) {
                const targetSquare = render.getSquareFromPos(targetPos);
                var targetPiece = board.getPiece(targetSquare);
                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else if (targetPiece.getColor() != color) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .Capture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                }
            }
        }

        // Castling moves
        const castlingRights = if (color == PieceColor.White) (board.castlingRights & 0b0011) else ((board.castlingRights & 0b1100) >> 2);
        for (0..2) |i| { // 0 = King-side, 1 = Queen-side
            if (castlingRights & (@as(u2, 0b01) << @intCast(i)) != 0) {
                const kingSquare = self.selectedSquare.square;
                const direction: i32 = if (i == 0) 1 else -1;
                const rookSquareDelta: i32 = if (i == 0) 3 else -4;

                var emptySquares = std.BoundedArray(u6, 3){};

                var j: i32 = direction;
                while (j * direction < rookSquareDelta * direction) {
                    emptySquares.append(@intCast(kingSquare + j)) catch std.debug.panic("Failed to append square", .{});
                    j += direction;
                }

                const squares = emptySquares.constSlice();
                for (0..squares.len) |x| {
                    const square = squares[x];
                    if (board.getPiece(square).valid) {
                        break;
                    }
                } else {
                    if (i == 0) {
                        self.pseudoLegalMoves.append(Move.init(
                            kingSquare,
                            @intCast(kingSquare + 2 * direction),
                            board,
                            .{ .KingCastle = .{} },
                        )) catch std.debug.panic("Failed to append move", .{});
                    } else {
                        self.pseudoLegalMoves.append(Move.init(
                            kingSquare,
                            @intCast(kingSquare + 2 * direction),
                            board,
                            .{ .QueenCastle = .{} },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                }
            }
        }
    }

    fn updatePseudoLegalMoves(self: *PlayerController, board: *Board, render: *Render) void {
        // clear the pseudoLegalMoves
        self.pseudoLegalMoves.clear();

        if (self.selectedSquare.isSelected) {
            var piece = board.getPiece(self.selectedSquare.square);

            if (!piece.valid) {
                return;
            }

            if (piece.getColor() != board.pieceToMove) {
                return;
            }

            switch (piece.getPieceType()) {
                PieceType.Pawn => self.updatePawnMoves(board, render),
                PieceType.Knight => self.updateKnightMoves(board, render),
                PieceType.Bishop => self.updateBishopMoves(board, render),
                PieceType.Rook => self.updateRookMoves(board, render),
                PieceType.Queen => {
                    self.updateBishopMoves(board, render);
                    self.updateRookMoves(board, render);
                },
                PieceType.King => self.updateKingMoves(board, render),
            }
        }
    }

    fn updateSelectedSquare(self: *PlayerController, render: *Render, board: *Board) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            if (self.isMouseOverBoard()) {
                const pos = self.getMousePosition();
                const square = render.getSquareFromPos(pos);

                if (self.selectedSquare.isSelected) {
                    if (self.selectedSquare.square == square) {
                        self.selectedSquare.clear();
                        self.pseudoLegalMoves.clear();
                    }

                    const moves = self.pseudoLegalMoves.constSlice();
                    for (0..moves.len) |i| {
                        const move: Move = moves[i];
                        if (move.to == square) {
                            board.makeMove(move);
                            self.selectedSquare.clear();
                            self.pseudoLegalMoves.clear();

                            return;
                        }
                    }
                    self.selectedSquare.setSquare(square);
                    self.updatePseudoLegalMoves(board, render);
                } else {
                    self.selectedSquare.setSquare(square);
                    self.updatePseudoLegalMoves(board, render);
                }
            }
        }
    }

    pub fn update(self: *PlayerController, deltaTime: f32, render: *Render, board: *Board) void {
        _ = deltaTime;

        self.updateSelectedSquare(render, board);

        // Print the binary representation of castlingRights
        // std.log.info("Castling rights: {b:4}", .{board.castlingRights});
    }

    fn isMouseOverBoard(self: *PlayerController) bool {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return (mousePos.x >= self.offset.x and
            mousePos.x < self.offset.x + self.tileSize * 8 and
            mousePos.y >= self.offset.y and
            mousePos.y < self.offset.y + self.tileSize * 8);
    }

    fn getMousePosition(self: *PlayerController) IVector2 {
        if (!self.isMouseOverBoard()) {
            return IVector2.init(0, 0);
        }

        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        const x = @as(u6, @intCast(@divFloor(mousePos.x - self.offset.x, self.tileSize)));
        const y = @as(u6, @intCast(@divFloor(mousePos.y - self.offset.y, self.tileSize)));
        return IVector2.init(x, y);
    }

    pub fn countPossibleMoves(self: *PlayerController, board: *Board, render: *Render, depth: u8) u64 {
        if (depth == 0) {
            return 1; // Base case: one possibility at depth 0
        }

        var count: u64 = 0;

        for (0..64) |s| {
            const square = @as(u6, @intCast(s));

            // Dont need to verify if the square is valid,
            //  because updatePseudoLegalMoves already does that
            self.selectedSquare.setSquare(square);
            self.updatePseudoLegalMoves(board, render);

            const moves = self.pseudoLegalMoves.constSlice();
            for (0..moves.len) |i| {
                const move: Move = moves[i];

                // Make the move
                board.makeMove(move);

                // std.debug.print("Move: {d} -> {d}\n", .{ move.from, move.to });
                // Render.print(board);

                // Recursively count moves at the next depth
                count += self.countPossibleMoves(board, render, depth - 1);

                if (board.lastMoves.pop()) |lastMove| {
                    board.undoMove(lastMove);
                }
            }
        }

        return count;
    }
};
