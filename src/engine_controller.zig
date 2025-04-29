const std = @import("std");
const p = @import("piece.zig");
const b = @import("board.zig");
const r = @import("render.zig");
const m = @import("move.zig");

const Board = b.Board;
const Render = r.Render;
const Move = m.Move;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const Bitboard = b.Bitboard;

pub const EngineController = struct {
    board: *Board,
    timeSinceLastMove: f32 = 0,
    pseudoLegalMoves: std.ArrayList(Move),

    pub fn init(board: *Board) EngineController {
        return EngineController{
            .board = board,
            .pseudoLegalMoves = std.ArrayList(Move).init(std.heap.c_allocator),
        };
    }

    pub fn deinit(self: *EngineController) void {
        self.pseudoLegalMoves.deinit();
    }

    fn whitePawnSinglePushTarget(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
        return Board.shiftNorth(whitePawns) & emptySquares;
    }

    fn blackPawnSinglePushTarget(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
        return Board.shiftSouth(blackPawns) & emptySquares;
    }

    fn whitePawnDoublePushTarget(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
        const rank4: Bitboard = 0x00000000FF000000;
        const singlePushTarget = EngineController.whitePawnSinglePushTarget(whitePawns, emptySquares);
        return Board.shiftNorth(singlePushTarget) & emptySquares & rank4;
    }

    fn blackPawnDoublePushTarget(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
        const rank5: Bitboard = 0x000000FF00000000;
        const singlePushTarget = EngineController.blackPawnSinglePushTarget(blackPawns, emptySquares);
        return Board.shiftSouth(singlePushTarget) & emptySquares & rank5;
    }

    fn whitePawnAble2Push(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
        return Board.shiftSouth(emptySquares) & whitePawns;
    }

    fn blackPawnAble2Push(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
        return Board.shiftNorth(emptySquares) & blackPawns;
    }

    fn whitePawnAble2DblPush(whitePawns: Bitboard, emptySquares: Bitboard) Bitboard {
        const rank4: Bitboard = 0x00000000FF000000;
        const emptyRank3: Bitboard = Board.shiftSouth(emptySquares & rank4) & emptySquares;
        return EngineController.whitePawnAble2Push(whitePawns, emptyRank3);
    }

    fn blackPawnAble2DblPush(blackPawns: Bitboard, emptySquares: Bitboard) Bitboard {
        const rank5: Bitboard = 0x000000FF00000000;
        const emptyRank4: Bitboard = Board.shiftNorth(emptySquares & rank5) & emptySquares;
        return EngineController.blackPawnAble2Push(blackPawns, emptyRank4);
    }

    // TODO: Implement the parallel pawn push generation
    // https://www.chessprogramming.org/General_Setwise_Operations
    // https://www.chessprogramming.org/Pawn_Pushes_(Bitboards)#GeneralizedPush
    fn genPawnPushes(self: *EngineController, colorToMove: PieceColor) void {
        const emptySquares = self.board.getEmptySquares();

        const pawnBitboard = self.board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        var singlePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => EngineController.whitePawnSinglePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => EngineController.blackPawnSinglePushTarget(pawnBitboard, emptySquares),
        };
        var doublePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => EngineController.whitePawnDoublePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => EngineController.blackPawnDoublePushTarget(pawnBitboard, emptySquares),
        };

        var pawnAble2Push: Bitboard = switch (colorToMove) {
            PieceColor.White => EngineController.whitePawnAble2Push(pawnBitboard, emptySquares),
            PieceColor.Black => EngineController.blackPawnAble2Push(pawnBitboard, emptySquares),
        };
        var pawnAble2DblPush: Bitboard = switch (colorToMove) {
            PieceColor.White => EngineController.whitePawnAble2DblPush(pawnBitboard, emptySquares),
            PieceColor.Black => EngineController.blackPawnAble2DblPush(pawnBitboard, emptySquares),
        };

        // Generate quiet single push pawn moves
        while (singlePushTarget != 0 and pawnAble2Push != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnAble2Push));
            const targetSquare: u6 = @intCast(@ctz(singlePushTarget));
            const move = Move.init(
                originSquare,
                targetSquare,
                self.board,
                .{ .QuietMove = .{} },
            );
            self.pseudoLegalMoves.append(move) catch unreachable;
            singlePushTarget &= ~(@as(u64, 1) << targetSquare);
            pawnAble2Push &= ~(@as(u64, 1) << originSquare);
        }

        // Generate quiet double push pawn moves
        while (doublePushTarget != 0 and pawnAble2DblPush != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnAble2DblPush));
            const targetSquare: u6 = @intCast(@ctz(doublePushTarget));
            const move = Move.init(
                originSquare,
                targetSquare,
                self.board,
                .{ .QuietMove = .{} },
            );
            self.pseudoLegalMoves.append(move) catch unreachable;
            doublePushTarget &= ~(@as(u64, 1) << targetSquare);
            pawnAble2DblPush &= ~(@as(u64, 1) << originSquare);
        }
    }

    pub fn genMoves(self: *EngineController) void {
        self.pseudoLegalMoves.clearRetainingCapacity();
        const colorToMove = self.board.pieceToMove;
        self.genPawnPushes(colorToMove);
    }

    pub fn makeRandomMove(self: *EngineController) void {
        if (self.pseudoLegalMoves.items.len == 0) {
            return;
        }

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, self.pseudoLegalMoves.items.len);
        const move = self.pseudoLegalMoves.items[randomIndex];
        self.board.makeMove(move);
    }

    pub fn update(self: *EngineController, deltaTime: f32) void {
        if (self.timeSinceLastMove >= 1.0) {
            self.timeSinceLastMove = 0;
            self.makeRandomMove();
            self.genMoves();
        }
        self.timeSinceLastMove += deltaTime;
    }
};
