const std = @import("std");
const rl = @import("raylib");
const iv = @import("ivector.zig");
const p = @import("piece.zig");
const b = @import("board.zig");
const m = @import("move.zig");
const r = @import("render.zig");
const ss = @import("selected_square.zig");
const pc = @import("player_controller.zig");
const ec = @import("engine_controller.zig");
const gs = @import("game_state.zig");
const mg = @import("move_gen.zig");

const IVector2 = iv.IVector2;
const SelectedSquare = ss.SelectedSquare;
const Move = m.Move;
const Render = r.Render;
const Board = b.Board;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const MoveCode = m.MoveCode;
const MoveGen = mg.MoveGen;

pub const PlayerController = struct {
    selectedSquare: SelectedSquare = SelectedSquare.init(),
    moveGen: MoveGen,
    board: *Board,
    render: *Render,
    _madeMove: bool = false,

    pub fn init(board: *Board, render: *Render) PlayerController {
        return PlayerController{
            .board = board,
            .render = render,
            .moveGen = MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *PlayerController) void {
        self.moveGen.deinit();
    }

    pub fn genMoves(self: *PlayerController) void {
        self.moveGen.update(self.board);
    }

    fn updateBoardInteraction(self: *PlayerController) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            if (self.isMouseOverBoard()) {
                const pos = self.getMousePosition();
                const square = self.render.getSquareFromPos(pos);

                if (self.selectedSquare.isSelected) {
                    if (self.selectedSquare.square == square) {
                        self.selectedSquare.clear();
                    }

                    std.debug.print("Number of possible moves to chose from: {}\n", .{self.moveGen.pseudoLegalMoves.items.len});

                    for (self.moveGen.pseudoLegalMoves.items) |move| {
                        if (move.from == self.selectedSquare.square and move.to == square) {
                            self.board.makeMove(move);
                            self.selectedSquare.clear();
                            self.genMoves();
                            self._madeMove = true;
                            return;
                        }
                    }
                    self.selectedSquare.setSquare(square);
                } else {
                    self.selectedSquare.setSquare(square);
                }
            } else {
                self.selectedSquare.clear();
            }
        }
    }

    pub fn madeMove(self: *PlayerController) bool {
        const ret = self._madeMove;
        self._madeMove = false;
        return ret;
    }

    pub fn update(self: *PlayerController, deltaTime: f32) void {
        _ = deltaTime;

        self.updateBoardInteraction();
    }

    fn isMouseOverBoard(self: *PlayerController) bool {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return (mousePos.x >= self.render.offset.x and
            mousePos.x < self.render.offset.x + self.render.tileSize * 8 and
            mousePos.y >= self.render.offset.y and
            mousePos.y < self.render.offset.y + self.render.tileSize * 8);
    }

    fn getMousePosition(self: *PlayerController) IVector2 {
        if (!self.isMouseOverBoard()) {
            return IVector2.init(0, 0);
        }

        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        const x = @as(u6, @intCast(@divFloor(mousePos.x - self.render.offset.x, self.render.tileSize)));
        const y = @as(u6, @intCast(@divFloor(mousePos.y - self.render.offset.y, self.render.tileSize)));
        return IVector2.init(x, y);
    }
};
