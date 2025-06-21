const std = @import("std");
const core = @import("core.zig");
const utils = @import("utils/utils.zig");

const pawnUtils = utils.pawn;
const knightUtils = utils.knight;
const rookUtils = utils.rook;
const bishopUtils = utils.bishop;
const kingUtils = utils.king;
const shiftUtils = utils.shift;
const checkUtils = utils.check;

const Board = core.Board;
const Move = core.types.Move;
const MoveCode = core.types.MoveCode;
const Piece = core.types.Piece;
const PieceColor = core.types.PieceColor;
const PieceType = core.types.PieceType;
const Bitboard = core.types.Bitboard;

pub const MoveGen = struct {
    pseudoLegalMoves: std.ArrayList(Move),

    pub fn init(allocator: std.mem.Allocator) MoveGen {
        return MoveGen{
            .pseudoLegalMoves = std.ArrayList(Move).init(allocator),
        };
    }

    pub fn deinit(self: *MoveGen) void {
        self.pseudoLegalMoves.deinit();
    }

    pub fn clear(self: *MoveGen) void {
        self.pseudoLegalMoves.clearRetainingCapacity();
    }

    pub fn update(self: *MoveGen, board: *Board) void {
        self.clear();
        self.genPawnPushes(board);
        self.genPawnAttacks(board);
        self.genKnightMoves(board);
        self.genRookMoves(board);
        self.genBishopMoves(board);
        self.genQueenMoves(board);
        self.genKingMoves(board);
    }

    fn genPawnPushes(self: *MoveGen, board: *Board) void {
        const emptySquares = board.getEmptySquares();
        const colorToMove = board.pieceToMove;

        const pawnBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        var singlePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnSinglePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => pawnUtils.blackPawnSinglePushTarget(pawnBitboard, emptySquares),
        };
        var doublePushTarget: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnDoublePushTarget(pawnBitboard, emptySquares),
            PieceColor.Black => pawnUtils.blackPawnDoublePushTarget(pawnBitboard, emptySquares),
        };

        var pawnAble2Push: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnAble2Push(pawnBitboard, emptySquares),
            PieceColor.Black => pawnUtils.blackPawnAble2Push(pawnBitboard, emptySquares),
        };
        var pawnAble2DblPush: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnAble2DblPush(pawnBitboard, emptySquares),
            PieceColor.Black => pawnUtils.blackPawnAble2DblPush(pawnBitboard, emptySquares),
        };

        // Generate quiet single push pawn moves
        while (singlePushTarget != 0 and pawnAble2Push != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnAble2Push));
            const targetSquare: u6 = @intCast(@ctz(singlePushTarget));

            var move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .QuietMove = .{} },
            );

            if (checkUtils.isWhiteOrBlackPromotionSquare(targetSquare)) {
                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenPromotion = .{} },
                )) catch unreachable;

                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .BishopPromotion = .{} },
                )) catch unreachable;

                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .KnightPromotion = .{} },
                )) catch unreachable;

                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .RookPromotion = .{} },
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
                board,
                .{ .DoublePawnPush = .{} },
            );
            self.pseudoLegalMoves.append(move) catch unreachable;
            doublePushTarget &= ~(@as(u64, 1) << targetSquare);
            pawnAble2DblPush &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genPawnAttacks(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;

        const pawnBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Pawn)];

        const pawnEastAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnEastAttack(pawnBitboard),
            PieceColor.Black => pawnUtils.blackPawnEastAttack(pawnBitboard),
        };

        const pawnWestAttacks: Bitboard = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnWestAttack(pawnBitboard),
            PieceColor.Black => pawnUtils.blackPawnWestAttack(pawnBitboard),
        };

        var oppositeColorBitboard = board.getColorBitboard(colorToMove.opposite());

        // Check the EnPassant target square as valid
        if (board.enPassantTarget) |enPassantTarget| {
            oppositeColorBitboard |= (@as(u64, 1) << enPassantTarget);
        }

        var pawnEastAttackTarget = pawnEastAttacks & oppositeColorBitboard;
        var pawnEastAble2Capture = switch (colorToMove) {
            PieceColor.White => pawnUtils.whitePawnAble2CaptureEast(pawnEastAttackTarget),
            PieceColor.Black => pawnUtils.blackPawnAble2CaptureEast(pawnEastAttackTarget),
        };

        while (pawnEastAttackTarget != 0 and pawnEastAble2Capture != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnEastAble2Capture));
            const targetSquare: u6 = @intCast(@ctz(pawnEastAttackTarget));

            const capturedPiece = board.getPiece(targetSquare);

            var move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            if (!capturedPiece.valid) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .EnPassant = .{
                        .capturedPiece = Piece.init(
                            colorToMove.opposite(),
                            PieceType.Pawn,
                        ),
                    } },
                );
            }

            if (checkUtils.isWhiteOrBlackPromotionSquare(targetSquare)) {
                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                )) catch unreachable;

                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .BishopPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                )) catch unreachable;

                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .KnightPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                )) catch unreachable;

                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .RookPromotionCapture = .{
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
            PieceColor.White => pawnUtils.whitePawnAble2CaptureWest(pawnWestAttackTarget),
            PieceColor.Black => pawnUtils.blackPawnAble2CaptureWest(pawnWestAttackTarget),
        };

        while (pawnWestAttackTarget != 0 and pawnWestAble2Capture != 0) {
            const originSquare: u6 = @intCast(@ctz(pawnWestAble2Capture));
            const targetSquare: u6 = @intCast(@ctz(pawnWestAttackTarget));

            const capturedPiece = board.getPiece(targetSquare);

            var move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            // Condition to be an enPassant capture
            if (!capturedPiece.valid) {
                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .EnPassant = .{
                        .capturedPiece = Piece.init(
                            colorToMove.opposite(),
                            PieceType.Pawn,
                        ),
                    } },
                );
            }

            // Capture with promotion
            if (checkUtils.isWhiteOrBlackPromotionSquare(targetSquare)) {
                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                )) catch unreachable;

                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .BishopPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                )) catch unreachable;

                self.pseudoLegalMoves.append(Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .KnightPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                )) catch unreachable;

                move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .RookPromotionCapture = .{
                        .capturedPiece = capturedPiece,
                    } },
                );
            }

            self.pseudoLegalMoves.append(move) catch unreachable;
            pawnWestAttackTarget &= ~(@as(u64, 1) << targetSquare);
            pawnWestAble2Capture &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genKnightMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var knightBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Knight)];
        const availableSquares = ~board.getColorBitboard(colorToMove);

        while (knightBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(knightBitboard));
            var attackTarget = knightUtils.knightAttacks(@as(u64, 1) << originSquare);
            attackTarget &= availableSquares;

            var captureTarget = attackTarget & board.getColorBitboard(colorToMove.opposite());
            attackTarget &= ~captureTarget;

            // Capture moves
            while (captureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(captureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                captureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            // Quiet moves
            while (attackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(attackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                attackTarget &= ~(@as(u64, 1) << targetSquare);
            }
            knightBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genRookMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var rookBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Rook)];

        while (rookBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(rookBitboard));

            var attackTarget = rookUtils.rookAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );

            var captureTarget = attackTarget & board.getColorBitboard(colorToMove.opposite());

            attackTarget &= ~captureTarget;

            // Capture moves
            while (captureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(captureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                captureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            // Quiet Moves
            while (attackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(attackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                attackTarget &= ~(@as(u64, 1) << targetSquare);
            }

            rookBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genBishopMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var bishopBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Bishop)];

        while (bishopBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(bishopBitboard));

            var attackTarget = bishopUtils.bishopAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );

            var captureTarget = attackTarget & board.getColorBitboard(colorToMove.opposite());
            attackTarget &= ~captureTarget;

            // Capture moves
            while (captureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(captureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                captureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            while (attackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(attackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                attackTarget &= ~(@as(u64, 1) << targetSquare);
            }

            bishopBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genQueenMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        var queenBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.Queen)];

        while (queenBitboard != 0) {
            const originSquare: u6 = @intCast(@ctz(queenBitboard));

            var rookAttackTarget = rookUtils.rookAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );
            var rookCaptureTarget = rookAttackTarget & board.getColorBitboard(colorToMove.opposite());
            rookAttackTarget &= ~rookCaptureTarget;

            // Capture moves
            while (rookCaptureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(rookCaptureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                rookCaptureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            // Quiet Moves
            while (rookAttackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(rookAttackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                rookAttackTarget &= ~(@as(u64, 1) << targetSquare);
            }

            var bishopAttackTarget = bishopUtils.bishopAttacks(
                originSquare,
                board.getColorBitboard(colorToMove),
                board.getColorBitboard(colorToMove.opposite()),
            );
            var bishopCaptureTarget = bishopAttackTarget & board.getColorBitboard(colorToMove.opposite());
            bishopAttackTarget &= ~bishopCaptureTarget;

            // Capture moves
            while (bishopCaptureTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(bishopCaptureTarget));

                const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .Capture = .{ .capturedPiece = capturedPiece } },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                bishopCaptureTarget &= ~(@as(u64, 1) << targetSquare);
            }

            while (bishopAttackTarget != 0) {
                const targetSquare: u6 = @intCast(@ctz(bishopAttackTarget));

                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QuietMove = .{} },
                );

                self.pseudoLegalMoves.append(move) catch unreachable;

                bishopAttackTarget &= ~(@as(u64, 1) << targetSquare);
            }

            queenBitboard &= ~(@as(u64, 1) << originSquare);
        }
    }

    fn genKingMoves(self: *MoveGen, board: *Board) void {
        const colorToMove = board.pieceToMove;
        const kingBitboard = board.boards[@intFromEnum(colorToMove)][@intFromEnum(PieceType.King)];
        const availableSquares = ~board.getColorBitboard(colorToMove);
        const occupiedSquares = board.getColorBitboard(colorToMove) |
            board.getColorBitboard(colorToMove.opposite());

        if (kingBitboard == 0) {
            return;
        }

        // Obtaining king attacks
        const originSquare: u6 = @intCast(@ctz(kingBitboard));
        var attackTarget = kingUtils.kingAttacks(kingBitboard) & availableSquares;
        var captureTarget = attackTarget & board.getColorBitboard(colorToMove.opposite());
        attackTarget &= ~captureTarget;

        // Capture moves
        while (captureTarget != 0) {
            const targetSquare: u6 = @intCast(@ctz(captureTarget));

            const capturedPiece = board.getPieceFromColor(targetSquare, colorToMove.opposite());

            const move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .Capture = .{ .capturedPiece = capturedPiece } },
            );

            self.pseudoLegalMoves.append(move) catch unreachable;

            captureTarget &= ~(@as(u64, 1) << targetSquare);
        }

        // Quiet Moves
        while (attackTarget != 0) {
            const targetSquare: u6 = @intCast(@ctz(attackTarget));

            const move = Move.init(
                originSquare,
                targetSquare,
                board,
                .{ .QuietMove = .{} },
            );

            self.pseudoLegalMoves.append(move) catch unreachable;

            attackTarget &= ~(@as(u64, 1) << targetSquare);
        }

        const castlingRightsMask = switch (colorToMove) {
            PieceColor.White => @as(u8, 0b00000011),
            PieceColor.Black => @as(u8, 0b00001100),
        };
        const castlingRights = (board.castlingRights & castlingRightsMask) >> @intCast(@ctz(castlingRightsMask));

        if (castlingRights == 0) {
            return;
        }

        // Can castle king side - east
        if (castlingRights & 0b01 != 0) {
            const eastCastleMask = shiftUtils.shiftEast(kingBitboard) |
                shiftUtils.shiftEast(shiftUtils.shiftEast(kingBitboard));

            const eastCastleCheckMask = shiftUtils.shiftEast(kingBitboard) |
                shiftUtils.shiftEast(shiftUtils.shiftEast(kingBitboard)) | kingBitboard;

            const haveIntermediaryCheck = checkUtils.areSquaresAttacked(
                eastCastleCheckMask,
                board,
                board.pieceToMove.opposite(),
            );

            if (!haveIntermediaryCheck and ~occupiedSquares & eastCastleMask == eastCastleMask) {
                const targetSquare: u6 = @intCast(@ctz(shiftUtils.shiftEast(shiftUtils.shiftEast(kingBitboard))));
                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .KingCastle = .{} },
                );
                self.pseudoLegalMoves.append(move) catch unreachable;
            }
        }

        // Can castle queen side - west
        if (castlingRights & 0b10 != 0) {
            const westCastleMask = shiftUtils.shiftWest(kingBitboard) |
                shiftUtils.shiftWest(shiftUtils.shiftWest(kingBitboard)) |
                shiftUtils.shiftWest(shiftUtils.shiftWest(shiftUtils.shiftWest(kingBitboard)));

            const westCastleCheckMask = shiftUtils.shiftWest(kingBitboard) |
                shiftUtils.shiftWest(shiftUtils.shiftWest(kingBitboard)) | kingBitboard;
            const haveIntermediaryCheck = checkUtils.areSquaresAttacked(
                westCastleCheckMask,
                board,
                board.pieceToMove.opposite(),
            );

            if (!haveIntermediaryCheck and ~occupiedSquares & westCastleMask == westCastleMask) {
                const targetSquare: u6 = @intCast(@ctz(shiftUtils.shiftWest(shiftUtils.shiftWest(kingBitboard))));
                const move = Move.init(
                    originSquare,
                    targetSquare,
                    board,
                    .{ .QueenCastle = .{} },
                );
                self.pseudoLegalMoves.append(move) catch unreachable;
            }
        }
    }
};
