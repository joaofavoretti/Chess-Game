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
    tileSize: i32,
    offset: IVector2,
    selectedSquare: SelectedSquare = SelectedSquare.init(),
    moveGen: MoveGen,
    _madeMove: bool = false,

    pub fn init(baseRender: *Render) PlayerController {
        return PlayerController{
            .tileSize = baseRender.tileSize,
            .offset = baseRender.offset,
            .moveGen = MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *PlayerController) void {
        self.moveGen.deinit();
    }

    fn genMoves(self: *PlayerController, board: *Board) void {
        self.moveGen.update(board);
    }

    fn updateBoardInteraction(self: *PlayerController, render: *Render, board: *Board) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            if (self.isMouseOverBoard()) {
                const pos = self.getMousePosition();
                const square = render.getSquareFromPos(pos);

                if (self.selectedSquare.isSelected) {
                    if (self.selectedSquare.square == square) {
                        self.selectedSquare.clear();
                    }

                    for (self.moveGen.pseudoLegalMoves.items) |move| {
                        if (move.from == self.selectedSquare.square and move.to == square) {
                            board.makeMove(move);
                            self.selectedSquare.clear();
                            self.genMoves(board);
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
        self.madeMove = false;
        return ret;
    }

    pub fn update(self: *PlayerController, deltaTime: f32, render: *Render, board: *Board) void {
        _ = deltaTime;

        self.updateBoardInteraction(render, board);
    }

    fn isMouseOverBoard(self: *PlayerController) bool {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return (mousePos.x >= self.offset.x and
            mousePos.x < self.offset.x + self.tileSize * 8 and
            mousePos.y >= self.offset.y and
            mousePos.y < self.offset.y + self.tileSize * 8);
    }

    fn getMousePosition(self: *PlayerController) IVector2 {
        if (!self.isMouseOverBoard()) {
            return IVector2.init(0, 0);
        }

        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        const x = @as(u6, @intCast(@divFloor(mousePos.x - self.offset.x, self.tileSize)));
        const y = @as(u6, @intCast(@divFloor(mousePos.y - self.offset.y, self.tileSize)));
        return IVector2.init(x, y);
    }
};
