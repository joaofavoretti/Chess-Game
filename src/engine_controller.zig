const std = @import("std");
const rl = @import("raylib");
const p = @import("piece.zig");
const b = @import("board.zig");
const r = @import("render.zig");
const m = @import("move.zig");
const pawnPushUtils = @import("engine_utils/pawn_push.zig");
const pawnAttackUtils = @import("engine_utils/pawn_attack.zig");

const Board = b.Board;
const Render = r.Render;
const Move = m.Move;
const MoveCode = m.MoveCode;
const Piece = p.Piece;
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

    fn isWhiteOrBlackPromotionSquare(targetSquare: u6) bool {
        return (targetSquare & 0b111000) == 0b111000 or
            (targetSquare ^ 0b111000) & 0b111000 == 0b111000;
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

            var move = Move.init(
                originSquare,
                targetSquare,
                self.board,
                .{ .QuietMove = .{} },
            );

            if (EngineController.isWhiteOrBlackPromotionSquare(targetSquare)) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    self.board,
                    .{ .QueenPromotion = .{} },
                );
            }

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
            PieceColor.White => pawnAttackUtils.whitePawnEastAttack(pawnBitboard),
            PieceColor.Black => pawnAttackUtils.blackPawnEastAttack(pawnBitboard),
        };

        const pawnWestAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnWestAttack(pawnBitboard),
            PieceColor.Black => pawnAttackUtils.blackPawnWestAttack(pawnBitboard),
        };

        var oppositeColorBitboard = self.board.getColorBitboard(colorToMove.opposite());

        // Check the EnPassant target square as valid
        if (self.board.enPassantTarget) |enPassantTarget| {
            oppositeColorBitboard |= (@as(u64, 1) << enPassantTarget);
        }

        var pawnEastAttackTarget = pawnEastAttacks & oppositeColorBitboard;
        var pawnEastAble2Capture = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnAble2CaptureEast(pawnEastAttackTarget),
            PieceColor.Black => pawnAttackUtils.blackPawnAble2CaptureEast(pawnEastAttackTarget),
        };

        while (pawnEastAttackTarget != 0 and pawnEastAble2Capture != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnEastAble2Capture));
            const targetSquare: u6 = @intCast(@ctz(pawnEastAttackTarget));

            const capturedPiece = self.board.getPiece(targetSquare);

            var move = Move.init(
                originSquare,
                targetSquare,
                self.board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            if (!capturedPiece.valid) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    self.board,
                    .{ .EnPassant = .{
                        .capturedPiece = Piece.init(
                            colorToMove.opposite(),
                            PieceType.Pawn,
                        ),
                    } },
                );
            }

            if (EngineController.isWhiteOrBlackPromotionSquare(targetSquare)) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    self.board,
                    .{ .QueenPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                );
            }

            self.pseudoLegalMoves.append(move) catch unreachable;
            pawnEastAttackTarget &= ~(@as(u64, 1) << targetSquare);
            pawnEastAble2Capture &= ~(@as(u64, 1) << originSquare);
        }

        var pawnWestAttackTarget = pawnWestAttacks & oppositeColorBitboard;
        var pawnWestAble2Capture = switch (colorToMove) {
            PieceColor.White => pawnAttackUtils.whitePawnAble2CaptureWest(pawnWestAttackTarget),
            PieceColor.Black => pawnAttackUtils.blackPawnAble2CaptureWest(pawnWestAttackTarget),
        };

        while (pawnWestAttackTarget != 0 and pawnWestAble2Capture != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnWestAble2Capture));
            const targetSquare: u6 = @intCast(@ctz(pawnWestAttackTarget));

            const capturedPiece = self.board.getPiece(targetSquare);

            var move = Move.init(
                originSquare,
                targetSquare,
                self.board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            // Condition to be an enPassant capture
            if (!capturedPiece.valid) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    self.board,
                    .{ .EnPassant = .{
                        .capturedPiece = Piece.init(
                            colorToMove.opposite(),
                            PieceType.Pawn,
                        ),
                    } },
                );
            }

            // Capture with promotion
            if (EngineController.isWhiteOrBlackPromotionSquare(targetSquare)) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    self.board,
                    .{ .QueenPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                );
            }

            self.pseudoLegalMoves.append(move) catch unreachable;
            pawnWestAttackTarget &= ~(@as(u64, 1) << targetSquare);
            pawnWestAble2Capture &= ~(@as(u64, 1) << originSquare);
        }
    }

    // U64 knightAttacks(U64 knights) {
    //    U64 l1 = (knights >> 1) & C64(0x7f7f7f7f7f7f7f7f);
    //    U64 l2 = (knights >> 2) & C64(0x3f3f3f3f3f3f3f3f);
    //    U64 r1 = (knights << 1) & C64(0xfefefefefefefefe);
    //    U64 r2 = (knights << 2) & C64(0xfcfcfcfcfcfcfcfc);
    //    U64 h1 = l1 | r1;
    //    U64 h2 = l2 | r2;
    //    return (h1<<16) | (h1>>16) | (h2<<8) | (h2>>8);
    // }

    fn knightAttacks(knightBitboard: Bitboard) Bitboard {
        const l1 = (knightBitboard >> 1) & 0x7f7f7f7f7f7f7f7f;
        const l2 = (knightBitboard >> 2) & 0x3f3f3f3f3f3f3f3f;
        const r1 = (knightBitboard << 1) & 0xfefefefefefefefe;
        const r2 = (knightBitboard << 2) & 0xfcfcfcfcfcfcfcfc;
        const h1 = l1 | r1;
        const h2 = l2 | r2;
        return (h1 << 16) | (h1 >> 16) | (h2 << 8) | (h2 >> 8);
    }

    fn genKnightMoves(self: *EngineController, colorToMove: PieceColor) void {
        var knightBitboard = self.board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Knight)];
        const availableSquares = ~self.board.getColorBitboard(colorToMove);

        while (knightBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(knightBitboard));
            var attackTarget = EngineController.knightAttacks(@as(u64, 1) << originSquare);
            attackTarget &= availableSquares;

            while (attackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(attackTarget));

                var move = Move.init(
                    originSquare,
                    targetSquare,
                    self.board,
                    .{ .QuietMove = .{} },
                );

                const capturedPiece = self.board.getPiece(targetSquare);

                if (capturedPiece.valid) {
                    move = Move.init(
                        originSquare,
                        targetSquare,
                        self.board,
                        .{ .Capture = .{ .capturedPiece = capturedPiece } },
                    );
                }

                self.pseudoLegalMoves.append(move) catch unreachable;

                attackTarget &= ~(@as(u64, 1) << targetSquare);
            }
            knightBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    pub fn genMoves(self: *EngineController) void {
        self.pseudoLegalMoves.clearRetainingCapacity();
        const colorToMove = self.board.pieceToMove;
        self.genPawnPushes(colorToMove);
        self.genPawnAttacks(colorToMove);
        self.genKnightMoves(colorToMove);
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

        // self.board.pieceToMove = PieceColor.White;
    }

    pub fn update(self: *EngineController, deltaTime: f32) void {
        _ = deltaTime;

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            self.makeRandomMove();
            self.genMoves();
        }

        if (rl.isKeyPressed(rl.KeyboardKey.u)) {
            if (self.board.lastMoves.pop()) |lastMove| {
                self.board.undoMove(lastMove);
                self.genMoves();
            }
        }
    }
};
