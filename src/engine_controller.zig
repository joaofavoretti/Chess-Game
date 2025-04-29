const std = @import("std");
const p = @import("piece.zig");
const b = @import("board.zig");
const r = @import("render.zig");
const m = @import("move.zig");
const pawnPushUtils = @import("engine_utils/pawn_push.zig");

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

    // TODO: Implement the parallel pawn push generation
    // https://www.chessprogramming.org/General_Setwise_Operations
    // https://www.chessprogramming.org/Pawn_Pushes_(Bitboards)#GeneralizedPush
    fn genPawnPushes(self: *EngineController, colorToMove: PieceColor) void {
        const emptySquares = self.board.getEmptySquares();

        const pawnBitboard = self.board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        var singlePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnSinglePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnSinglePushTarget(pawnBitboard, emptySquares),
        };
        var doublePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnDoublePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnDoublePushTarget(pawnBitboard, emptySquares),
        };

        var pawnAble2Push: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnAble2Push(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnAble2Push(pawnBitboard, emptySquares),
        };
        var pawnAble2DblPush: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnPushUtils.whitePawnAble2DblPush(pawnBitboard, emptySquares),
            PieceColor.Black => pawnPushUtils.blackPawnAble2DblPush(pawnBitboard, emptySquares),
        };

        // Generate quiet single push pawn moves
        while (singlePushTarget != 0 and pawnAble2Push != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnAble2Push));
            const targetSquare: u6 = @intCast(@ctz(singlePushTarget));

            // Verify if the target square is a promotion square
            //  using bitwise operations
            // const isWhitePromotionSquare = (targetSquare & 0b111000) == 0b111000;
            // const isBlackPromotionSquare = (targetSquare ^ 0b111000) & 0b111000 == 0b111000;

            const move = Move.init(
                originSquare,
                targetSquare,
                self.board,
                .{ .QuietMove = .{} },
            );

            // if (isWhitePromotionSquare or isBlackPromotionSquare) {
            //     move = Move.init(
            //         originSquare,
            //         targetSquare,
            //         self.board,
            //         .{ .QueenPromotion = .{} },
            //     );
            // }

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
                .{ .DoublePawnPush = .{} },
            );
            self.pseudoLegalMoves.append(move) catch unreachable;
            doublePushTarget &= ~(@as(u64, 1) << targetSquare);
            pawnAble2DblPush &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genPawnAttacks(self: *EngineController, colorToMove: PieceColor) void {
        const pawnBitboard = self.board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        const pawnEastAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => Board.shiftEast(Board.shiftNorth(pawnBitboard)),
            PieceColor.Black => Board.shiftEast(Board.shiftSouth(pawnBitboard)),
        };

        const pawnWestAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => Board.shiftWest(Board.shiftNorth(pawnBitboard)),
            PieceColor.Black => Board.shiftWest(Board.shiftSouth(pawnBitboard)),
        };

        _ = pawnEastAttacks;
        _ = pawnWestAttacks;
    }

    pub fn genMoves(self: *EngineController) void {
        self.pseudoLegalMoves.clearRetainingCapacity();
        const colorToMove = self.board.pieceToMove;
        self.genPawnPushes(colorToMove);
        self.genPawnAttacks(colorToMove);
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

        self.board.pieceToMove = PieceColor.White;
    }

    pub fn update(self: *EngineController, deltaTime: f32) void {
        if (self.timeSinceLastMove >= 0.3) {
            self.timeSinceLastMove = 0;
            self.makeRandomMove();
            self.genMoves();
        }
        self.timeSinceLastMove += deltaTime;
    }
};
