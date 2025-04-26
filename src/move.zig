const std = @import("std");
const iv = @import("ivector.zig");
const p = @import("piece.zig");
const b = @import("board.zig");

const IVector2 = iv.IVector2;

const PieceType = p.PieceType;
const PieceTypeLength = p.PieceTypeLength;
const PieceColor = p.PieceColor;
const PieceColorLength = p.PieceColorLength;
const Piece = p.Piece;

const Bitboard = b.Bitboard;
const Board = b.Board;

pub const MoveCode = enum(u4) {
    // Bits: Promotion, Capture, Special 1, Special 2
    QuietMove = 0b0000,
    DoublePawnPush = 0b0001,
    KingCastle = 0b0010,
    QueenCastle = 0b0011,
    Capture = 0b0100,
    EnPassant = 0b0101,
    KnightPromotion = 0b1000,
    BishopPromotion = 0b1001,
    RookPromotion = 0b1010,
    QueenPromotion = 0b1011,
    KnightPromotionCapture = 0b1100,
    BishopPromotionCapture = 0b1101,
    RookPromotionCapture = 0b1110,
    QueenPromotionCapture = 0b1111,

    pub fn isCapture(self: MoveCode) bool {
        return (@intFromEnum(self) & 0b0100) != 0;
    }

    pub fn isPromotion(self: MoveCode) bool {
        return (@intFromEnum(self) & 0b1000) != 0;
    }
};

pub const MoveProps = union(MoveCode) {
    QuietMove: struct {},
    DoublePawnPush: struct {},
    KingCastle: struct {},
    QueenCastle: struct {},
    Capture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    EnPassant: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    KnightPromotion: struct {},
    BishopPromotion: struct {},
    RookPromotion: struct {},
    QueenPromotion: struct {},
    KnightPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    BishopPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    RookPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    QueenPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
};

pub const Move = struct {
    // Basic move data
    from: u6,
    to: u6,

    // Move type
    props: MoveProps,

    // Board state memory (I still dont know if I should)
    pieceToMove: PieceColor,
    castlingRights: u8,
    enPassantTarget: u6,
    halfMoveClock: u8,
    fullMoveNumber: u8,

    pub fn init(from: u6, to: u6, boardState: *Board, props: MoveProps) Move {
        return Move{
            .from = from,
            .to = to,
            .props = props,
            .pieceToMove = boardState.pieceToMove,
            .castlingRights = boardState.castlingRights,
            .enPassantTarget = boardState.enPassantTarget,
            .halfMoveClock = boardState.halfMoveClock,
            .fullMoveNumber = boardState.fullMoveNumber,
        };
    }

    pub fn isValid(self: *const Move) bool {
        return self.from != self.to;
    }

    pub fn getCode(self: *const Move) MoveCode {
        return @as(MoveCode, self.props);
    }

    pub fn getCapturedPiece(self: *const Move) Piece {
        return switch (self.getCode()) {
            MoveCode.Capture => self.props.Capture.capturedPiece,
            MoveCode.EnPassant => self.props.EnPassant.capturedPiece,
            MoveCode.KnightPromotionCapture => self.props.KnightPromotionCapture.capturedPiece,
            MoveCode.BishopPromotionCapture => self.props.BishopPromotionCapture.capturedPiece,
            MoveCode.RookPromotionCapture => self.props.RookPromotionCapture.capturedPiece,
            MoveCode.QueenPromotionCapture => self.props.QueenPromotionCapture.capturedPiece,
            else => Piece.initInvalid(),
        };
    }

    pub fn getLastCastlingRights(self: *const Move) u8 {
        return switch (self.getCode()) {
            MoveCode.KingCastle => self.props.KingCastle.lastCastlingRights,
            MoveCode.QueenCastle => self.props.QueenCastle.lastCastlingRights,
            else => 0,
        };
    }
};
