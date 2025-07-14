const std = @import("std");
const core = @import("core");

pub const PlayerHandler = struct {
    board: *core.Board,
    selectedSquare: core.types.SelectedSquare,
    moveGen: core.MoveGen,
    moveDecision: ?core.types.Move = null,

    pub fn init(board: *core.Board) PlayerHandler {
        return PlayerHandler{
            .board = board,
            .selectedSquare = core.types.SelectedSquare.init(),
            .moveGen = core.MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn setup(self: *PlayerHandler) void {
        self.moveGen.update(self.board);
    }

    pub fn deinit(self: *PlayerHandler) void {
        self.moveGen.deinit();
    }

    pub fn update(self: *PlayerHandler, deltaTime: f32) void {
        _ = self;
        _ = deltaTime;
    }

    pub fn decidedMove(self: *PlayerHandler) ?core.types.Move {
        const move = self.moveDecision;
        self.moveDecision = null;
        return move;
    }

    pub fn onBoardChange(self: *PlayerHandler) void {
        self.moveGen.update(self.board);
        self.selectedSquare.clear();
    }

    pub fn onSquareClick(self: *PlayerHandler, square: u6) void {
        if (self.selectedSquare.isSelected) {
            if (self.selectedSquare.square == square) {
                self.selectedSquare.clear();
                return;
            }

            for (self.moveGen.pseudoLegalMoves.items) |move| {
                if (move.from == self.selectedSquare.square and move.to == square) {
                    if (self.moveDecision == null) {
                        self.moveDecision = move;
                    } else {
                        std.log.warn("Move already decided, wait until the controller capture the change", .{});
                    }

                    self.selectedSquare.clear();

                    return;
                }
            }

            self.selectedSquare.setSquare(square);
        } else {
            self.selectedSquare.setSquare(square);
        }
    }
};
