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

pub const MoveProperties = union(MoveType) {
    Normal: struct {},
    DoublePawn: struct {},
    Capture: struct {
        capturedPiece: *Piece = undefined,
    },
    EnPassant: struct {
        capturedPiece: *Piece = undefined,
    },
    Castle: struct {
        rook: *Piece = undefined,
        rookFrom: IVector2 = IVector2.init(0, 0),
        rookTo: IVector2 = IVector2.init(0, 0),
    },
    Promotion: struct {
        promotedTo: PieceType = PieceType.Queen,
    },
};

pub const Move = struct {
    piece: *Piece,
    from: IVector2,
    to: IVector2,

    // IDEA: Add extra information if the move type requires
    properties: MoveProperties,

    pub fn init(piece: *Piece, from: IVector2, to: IVector2, properties: MoveProperties) Move {
        return Move{
            .piece = piece,
            .from = from,
            .to = to,
            .properties = properties,
        };
    }

    pub fn getType(self: Move) MoveType {
        return @as(MoveType, self.properties);
    }
};
