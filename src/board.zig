const std = @import("std");
const rl = @import("raylib");
const iv = @import("ivector.zig");
const pi = @import("piece.zig");
const b = @import("board.zig");
const m = @import("move.zig");
const r = @import("render.zig");
const ss = @import("selected_square.zig");
const pc = @import("player_controller.zig");
const ec = @import("engine_controller.zig");
const gs = @import("game_state.zig");

const PieceColorLength = pi.PieceColorLength;
const PieceTypeLength = pi.PieceTypeLength;
const PieceType = pi.PieceType;
const PieceColor = pi.PieceColor;
const Piece = pi.Piece;
const Move = m.Move;
const MoveCode = m.MoveCode;

pub const Bitboard = u64;

const notAFile: Bitboard = 0xfefefefefefefefe; // ~0x0101010101010101
const notHFile: Bitboard = 0x7f7f7f7f7f7f7f7f; // ~0x8080808080808080

pub const Board = struct {
    boards: [PieceColorLength][PieceTypeLength]Bitboard,
    pieceToMove: PieceColor,
    castlingRights: u8,
    enPassantTarget: ?u6,
    halfMoveClock: u8,
    fullMoveNumber: u8,
    lastMoves: std.ArrayList(Move),

    pub fn setPiece(self: *Board, color: PieceColor, piece: PieceType, square: u6) void {
        const one: u64 = 1;
        const setMask = one << square;
        const updatedBitboard = self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] | setMask;
        self.boards[@intFromEnum(color)][@intFromEnum(piece)] = updatedBitboard;
    }

    pub fn clearPiece(self: *Board, color: PieceColor, piece: PieceType, square: u6) void {
        const one: u64 = 1;
        const clearMask = one << square;
        const updatedBitboard = self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] & ~clearMask;
        self.boards[@intFromEnum(color)][@intFromEnum(piece)] = updatedBitboard;
    }

    pub fn getColorBitboard(self: *Board, color: PieceColor) Bitboard {
        var colorBitboard: Bitboard = 0;
        inline for (0..PieceTypeLength) |p| {
            colorBitboard |= self.boards[@as(usize, @intFromEnum(color))][p];
        }
        return colorBitboard;
    }

    pub fn shiftNorth(bitboard: Bitboard) Bitboard {
        return bitboard << 8;
    }

    pub fn shiftSouth(bitboard: Bitboard) Bitboard {
        return bitboard >> 8;
    }

    pub fn shiftEast(bitboard: Bitboard) Bitboard {
        return (bitboard & notHFile) << 1;
    }

    pub fn shiftNortheast(bitboard: Bitboard) Bitboard {
        return (bitboard & notHFile) << 9;
    }

    pub fn shiftSoutheast(bitboard: Bitboard) Bitboard {
        return (bitboard & notHFile) >> 7;
    }

    pub fn shiftWest(bitboard: Bitboard) Bitboard {
        return (bitboard & notAFile) >> 1;
    }

    pub fn shiftSouthwest(bitboard: Bitboard) Bitboard {
        return (bitboard & notAFile) >> 9;
    }

    pub fn shiftNorthwest(bitboard: Bitboard) Bitboard {
        return (bitboard & notAFile) << 7;
    }

    pub fn deinit(self: *Board) void {
        self.lastMoves.deinit();
    }

    pub fn getEmptySquares(self: *Board) Bitboard {
        var emptySquares: Bitboard = 0;
        inline for (0..PieceColorLength) |c| {
            inline for (0..PieceTypeLength) |p| {
                emptySquares |= self.boards[c][p];
            }
        }
        return ~emptySquares;
    }

    pub fn initFromFEN(fen: []const u8) Board {
        var tokenizer = std.mem.tokenizeAny(u8, fen, " ");
        const piecePlacement = tokenizer.next() orelse @panic("Invalid FEN: missing piece placement");
        const activeColor = tokenizer.next() orelse @panic("Invalid FEN: missing active color");
        const castlingRights = tokenizer.next() orelse @panic("Invalid FEN: missing castling rights");
        const enPassant = tokenizer.next() orelse @panic("Invalid FEN: missing en passant target");
        const halfMoveClock = tokenizer.next() orelse @panic("Invalid FEN: missing halfmove clock");
        const fullMoveNumber = tokenizer.next() orelse @panic("Invalid FEN: missing fullmove number");

        var board = Board{
            .boards = std.mem.zeroes([PieceColorLength][PieceTypeLength]Bitboard),
            .pieceToMove = if (activeColor[0] == 'w') PieceColor.White else PieceColor.Black,
            .castlingRights = 0,
            .enPassantTarget = if (enPassant[0] == '-') null else parseSquare(enPassant),
            .halfMoveClock = std.fmt.parseUnsigned(u8, halfMoveClock, 10) catch @panic("Invalid halfmove clock"),
            .fullMoveNumber = std.fmt.parseUnsigned(u8, fullMoveNumber, 10) catch @panic("Invalid fullmove number"),
            .lastMoves = std.ArrayList(Move).init(std.heap.page_allocator),
        };

        // Parse piece placement
        var rank: u8 = 7;
        var file: u8 = 0;
        for (piecePlacement) |c| {
            if (c == '/') {
                rank -= 1;
                file = 0;
            } else if (c >= '1' and c <= '8') {
                file += c - '0';
            } else {
                const color = if (std.ascii.isUpper(c)) PieceColor.White else PieceColor.Black;
                const piece = switch (std.ascii.toLower(c)) {
                    'p' => PieceType.Pawn,
                    'n' => PieceType.Knight,
                    'b' => PieceType.Bishop,
                    'r' => PieceType.Rook,
                    'q' => PieceType.Queen,
                    'k' => PieceType.King,
                    else => @panic("Invalid piece character"),
                };
                const square = @as(u6, @intCast(rank * 8 + file));
                board.setPiece(color, piece, square);
                file += 1;
            }
        }

        // Parse castling rights
        for (castlingRights) |c| {
            switch (c) {
                'K' => board.castlingRights |= 0b0001, // White king side
                'Q' => board.castlingRights |= 0b0010, // White queen side
                'k' => board.castlingRights |= 0b0100, // Black king side
                'q' => board.castlingRights |= 0b1000, // Black queen side
                '-' => {},
                else => @panic("Invalid castling rights"),
            }
        }

        return board;
    }

    pub fn parseSquare(square: []const u8) u6 {
        if (square.len != 2) @panic("Invalid square format");
        const file = square[0] - 'a';
        const rank = square[1] - '1';
        return @intCast(rank * 8 + file);
    }

    pub fn getPieceChar(self: *Board, square: u6) u8 {
        for (0..PieceColorLength) |c| {
            const color: PieceColor = @enumFromInt(c);
            for (0..PieceTypeLength) |p| {
                const piece: PieceType = @enumFromInt(p);
                const bitboard = self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))];
                if ((bitboard >> square) & 1 == 1) {
                    return switch (piece) {
                        PieceType.Pawn => if (color == PieceColor.White) 'P' else 'p',
                        PieceType.Knight => if (color == PieceColor.White) 'N' else 'n',
                        PieceType.Bishop => if (color == PieceColor.White) 'B' else 'b',
                        PieceType.Rook => if (color == PieceColor.White) 'R' else 'r',
                        PieceType.Queen => if (color == PieceColor.White) 'Q' else 'q',
                        PieceType.King => if (color == PieceColor.White) 'K' else 'k',
                    };
                }
            }
        }
        return 0;
    }

    pub fn getPiece(self: *Board, square: u6) Piece {
        for (0..PieceColorLength) |c| {
            const color: PieceColor = @enumFromInt(c);
            for (0..PieceTypeLength) |p| {
                const piece: PieceType = @enumFromInt(p);
                const bitboard = self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))];
                if ((bitboard >> square) & 1 == 1) {
                    return Piece.init(color, piece);
                }
            }
        }
        return Piece.initInvalid();
    }

    pub fn makeMove(board: *Board, move: Move) void {
        var piece = board.getPiece(move.from);

        if (piece.getColor() != board.pieceToMove) {
            return;
        }

        board.fullMoveNumber += if (piece.getColor() == PieceColor.Black) 1 else 0;
        board.halfMoveClock += if (piece.getColor() == PieceColor.White) 1 else 0;

        if (piece.valid) {
            board.clearPiece(piece.getColor(), piece.getPieceType(), move.from);
            board.setPiece(piece.getColor(), piece.getPieceType(), move.to);
        }

        // Disable castling rights if it is a king move
        if (piece.getPieceType() == PieceType.King) {
            board.castlingRights &= if (piece.getColor() == PieceColor.White) 0b1100 else 0b0011;
        }

        // If the moved rook is one of the unused ones for castle, update the castling rights
        if (piece.getPieceType() == PieceType.Rook) {
            const shiftAmount: u2 = if (piece.getColor() == PieceColor.White) 0 else 2;
            const castlingRightsMask = @as(u4, 0b0011) << shiftAmount;
            const opositeCastlingRightsMask = @as(u4, 0b1111) ^ castlingRightsMask;
            var castlingRights = (board.castlingRights & castlingRightsMask) >> shiftAmount;
            if (castlingRights != 0) {
                // The king wast moved
                const kingSquare: u6 = if (piece.getColor() == PieceColor.White) 4 else 60;
                const rookSquares = [2]u6{ kingSquare + 3, kingSquare - 4 };
                for (0..2) |i| { // 0 = King-side, 1 = Queen-side
                    const rookSquare = rookSquares[i];
                    if (move.from == rookSquare) {
                        // Update the castling rights to remove the side of the rook
                        castlingRights &= @as(u4, 0b0001) << @intCast(1 - i);
                        board.castlingRights &= (castlingRights << shiftAmount) | opositeCastlingRightsMask;
                    }
                }
            }
        }

        if (move.getCode().isCapture() or piece.getPieceType() == PieceType.Pawn) {
            board.halfMoveClock = 0;
        }

        // if the captured piece is a rook, I also need to update the castling rights
        if (move.getCode().isCapture() and move.getCapturedPiece().getPieceType() == PieceType.Rook) {
            const capturedRook = move.getCapturedPiece();
            const shiftAmount: u2 = if (capturedRook.getColor() == PieceColor.White) 0 else 2;
            const castlingRightsMask = @as(u4, 0b0011) << shiftAmount;
            const opositeCastlingRightsMask = @as(u4, 0b1111) ^ castlingRightsMask;
            var castlingRights = (board.castlingRights & castlingRightsMask) >> shiftAmount;
            if (castlingRights != 0) {
                // The king wast moved
                const kingSquare: u6 = if (capturedRook.getColor() == PieceColor.White) 4 else 60;
                const rookSquares = [2]u6{ kingSquare + 3, kingSquare - 4 };
                for (0..2) |i| { // 0 = King-side, 1 = Queen-side
                    const rookSquare = rookSquares[i];
                    if (move.to == rookSquare) {
                        std.log.info("Updating the castling rights according to the captured rook", .{});
                        // Update the castling rights to remove the side of the rook
                        castlingRights &= @as(u4, 0b0001) << @intCast(1 - i);
                        board.castlingRights &= (castlingRights << shiftAmount) | opositeCastlingRightsMask;
                    }
                }
            }
        }

        board.enPassantTarget = null;
        if (move.getCode() == MoveCode.DoublePawnPush) {
            const direction: i32 = if (piece.getColor() == PieceColor.White) -1 else 1;
            board.enPassantTarget = @intCast(move.to + direction * 8);
        }

        if (move.getCode().isCapture() and move.getCode() != MoveCode.EnPassant) {
            var capturedPiece = move.getCapturedPiece();
            board.clearPiece(capturedPiece.getColor(), capturedPiece.getPieceType(), move.to);
        }

        if (move.getCode() == MoveCode.EnPassant) {
            const direction: i32 = if (piece.getColor() == PieceColor.White) -1 else 1;
            const targetSquare: u6 = @intCast(move.to + direction * 8);
            var targetPiece = move.getCapturedPiece();
            board.clearPiece(targetPiece.getColor(), targetPiece.getPieceType(), targetSquare);
        }

        if (move.getCode().isPromotion()) {
            const pieceType = switch (move.getCode()) {
                MoveCode.KnightPromotion => PieceType.Knight,
                MoveCode.BishopPromotion => PieceType.Bishop,
                MoveCode.RookPromotion => PieceType.Rook,
                MoveCode.QueenPromotion => PieceType.Queen,
                MoveCode.KnightPromotionCapture => PieceType.Knight,
                MoveCode.BishopPromotionCapture => PieceType.Bishop,
                MoveCode.RookPromotionCapture => PieceType.Rook,
                MoveCode.QueenPromotionCapture => PieceType.Queen,
                else => unreachable,
            };
            board.clearPiece(piece.getColor(), piece.getPieceType(), move.to);
            board.setPiece(piece.getColor(), pieceType, move.to);
        }

        if (move.getCode() == MoveCode.KingCastle) {
            const direction: i32 = 1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 3);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, rookSquare);
        } else if (move.getCode() == MoveCode.QueenCastle) {
            const direction: i32 = -1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 4);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, rookSquare);
        }

        board.pieceToMove = board.pieceToMove.oposite();

        board.lastMoves.append(move) catch std.debug.panic("Failed to append move to lastMoves stack", .{});
    }

    pub fn undoMove(board: *Board, move: Move) void {
        var piece = board.getPiece(move.to);

        if (piece.getColor() != board.pieceToMove.oposite()) {
            return;
        }

        if (piece.valid) {
            board.clearPiece(piece.getColor(), piece.getPieceType(), move.to);
            board.setPiece(piece.getColor(), piece.getPieceType(), move.from);
        }

        if (move.getCode().isCapture() and move.getCode() != MoveCode.EnPassant) {
            var capturedPiece = move.getCapturedPiece();
            board.setPiece(capturedPiece.getColor(), capturedPiece.getPieceType(), move.to);
        }

        if (move.getCode() == MoveCode.EnPassant) {
            const direction: i32 = if (piece.getColor() == PieceColor.White) -1 else 1;
            const targetSquare: u6 = @intCast(move.to + direction * 8);
            var targetPiece = move.getCapturedPiece();
            board.setPiece(targetPiece.getColor(), targetPiece.getPieceType(), targetSquare);
        }

        if (move.getCode().isPromotion()) {
            const pieceType = switch (move.getCode()) {
                MoveCode.KnightPromotion => PieceType.Knight,
                MoveCode.BishopPromotion => PieceType.Bishop,
                MoveCode.RookPromotion => PieceType.Rook,
                MoveCode.QueenPromotion => PieceType.Queen,
                MoveCode.KnightPromotionCapture => PieceType.Knight,
                MoveCode.BishopPromotionCapture => PieceType.Bishop,
                MoveCode.RookPromotionCapture => PieceType.Rook,
                MoveCode.QueenPromotionCapture => PieceType.Queen,
                else => unreachable,
            };
            board.clearPiece(piece.getColor(), pieceType, move.from);
            board.setPiece(piece.getColor(), PieceType.Pawn, move.from);
        }

        if (move.getCode() == MoveCode.KingCastle) {
            const direction: i32 = 1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 3);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, rookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
        } else if (move.getCode() == MoveCode.QueenCastle) {
            const direction: i32 = -1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 4);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, rookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
        }
        board.pieceToMove = move.pieceToMove;
        board.castlingRights = move.castlingRights;
        board.enPassantTarget = move.enPassantTarget;
        board.halfMoveClock = move.halfMoveClock;
        board.fullMoveNumber = move.fullMoveNumber;
    }
};
