const std = @import("std");

const PieceType = enum {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
};
const PieceTypeLength = @typeInfo(PieceType).@"enum".fields.len;

const PieceColor = enum {
    White,
    Black,
};
const PieceColorLength = @typeInfo(PieceColor).@"enum".fields.len;

const Bitboard = u64;

const Board = struct {
    boards: [PieceColorLength][PieceTypeLength]Bitboard,
    pieceToMove: PieceColor,
    castlingRights: u8,
    enPassantTarget: u8,
    halfMoveClock: u8,
    fullMoveNumber: u8,

    fn setBitboard(self: *Board, color: PieceColor, piece: PieceType, bitboard: Bitboard) void {
        self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] = bitboard;
    }

    fn setPiece(self: *Board, color: PieceColor, piece: PieceType, square: u6) void {
        const one: u64 = 1;
        const bitboard = one << square;
        self.setBitboard(color, piece, self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] | bitboard);
    }

    fn initFromFEN(fen: []const u8) Board {
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
            .enPassantTarget = if (enPassant[0] == '-') 0 else parseSquare(enPassant),
            .halfMoveClock = std.fmt.parseUnsigned(u8, halfMoveClock, 10) catch @panic("Invalid halfmove clock"),
            .fullMoveNumber = std.fmt.parseUnsigned(u8, fullMoveNumber, 10) catch @panic("Invalid fullmove number"),
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
                'K' => board.castlingRights |= 0b0001,
                'Q' => board.castlingRights |= 0b0010,
                'k' => board.castlingRights |= 0b0100,
                'q' => board.castlingRights |= 0b1000,
                '-' => {},
                else => @panic("Invalid castling rights"),
            }
        }

        return board;
    }

    fn parseSquare(square: []const u8) u8 {
        if (square.len != 2) @panic("Invalid square format");
        const file = square[0] - 'a';
        const rank = square[1] - '1';
        return rank * 8 + file;
    }

    fn getPiece(self: *Board, square: u6) u8 {
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

    pub fn print(self: *Board) void {
        std.debug.print("Board:\n", .{});

        for (0..8) |rank| {
            for (0..8) |file| {
                const square = @as(u6, @intCast(rank * 8 + file));
                const piece = self.getPiece(square);
                if (piece != 0) {
                    std.debug.print("{c} ", .{piece});
                } else {
                    std.debug.print(". ", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};

pub fn main() void {
    const initialBoardFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    var board = Board.initFromFEN(initialBoardFEN);
    board.print();
}
