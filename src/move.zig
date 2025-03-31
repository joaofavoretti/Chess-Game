const std = @import("std");
const rl = @import("raylib");
const Piece = @import("piece.zig").Piece;
const PieceType = @import("piece.zig").PieceType;
const IVector2 = @import("utils/ivector.zig").IVector2;

pub const MoveType = enum {
    Normal,
    DoublePawn,
    Capture,
    EnPassant,
    Castle,
    Promotion,
};

pub const Move = struct {
    piece: *Piece,
    from: IVector2,
    to: IVector2,
    moveType: MoveType,

    // IDEA: Add extra information if the move type requires
    // properties: union(MoveType) {
    //     Normal: struct {
    //         isCheck: bool,
    //         isCheckmate: bool,
    //         isStalemate: bool,
    //     },
    //     Capture: struct {
    //         capturedPiece: *Piece,
    //     },
    //     EnPassant: struct {
    //         capturedPiece: *Piece,
    //     },
    //     Castle: struct {
    //         rook: *Piece,
    //         rookFrom: IVector2,
    //         rookTo: IVector2,
    //     },
    //     Promotion: struct {
    //         promotedTo: PieceType,
    //     },
    // },

    pub fn init(piece: *Piece, from: IVector2, to: IVector2, moveType: MoveType) Move {
        return Move{
            .piece = piece,
            .from = from,
            .to = to,
            .moveType = moveType,
        };
    }
};
