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
    type: MoveType,

    // IDEA: Add extra information if the move type requires
    properties: union(MoveType) {
        Normal: struct {
            isCheck: bool = false,
            isCheckmate: bool = false,
            isStalemate: bool = false,
        },
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
    },

    pub fn init(piece: *Piece, from: IVector2, to: IVector2, moveType: MoveType) Move {
        return Move{
            .piece = piece,
            .from = from,
            .to = to,
            .type = moveType,
            .properties = switch (moveType) {
                MoveType.Normal => .{
                    .Normal = .{},
                },
                MoveType.DoublePawn => .{
                    .DoublePawn = .{},
                },
                MoveType.Capture => .{
                    .Capture = .{},
                },
                MoveType.EnPassant => .{
                    .EnPassant = .{},
                },
                MoveType.Castle => .{
                    .Castle = .{},
                },
                MoveType.Promotion => .{
                    .Promotion = .{},
                },
            },
        };
    }
};
