const std = @import("std");
const core = @import("core");

const GameState = enum {
    AwaitingInput,
    EngineThinking,
    ProcessingMove,
    HoveringPiece,
    GameOver,
};

const PlayerType = enum {
    Human,
    Engine,
};

pub const GameController = struct {
    board: *core.Board,
    state: GameState,
    selectedSquare: core.types.SelectedSquare,
    moveGen: core.MoveGen,

    pub fn init(board: *core.Board) GameController {
        return GameController{
            .board = board,
            .state = .AwaitingInput,
            .selectedSquare = core.types.SelectedSquare.init(),
            .moveGen = core.MoveGen.init(std.heap.page_allocator),
        };
    }

    pub fn setup(self: *GameController) void {
        self.moveGen.update(self.board);
    }

    pub fn deinit(self: *GameController) void {
        self.moveGen.deinit();
        // Cleanup resources if necessary
    }

    pub fn update(self: *GameController, deltaTime: f32) void {
        _ = deltaTime;
        switch (self.state) {
            .AwaitingInput => {
                // Handle player input
                // If a move is made, transition to ProcessingMove
                // If the engine is thinking, transition to EngineThinking
            },
            .EngineThinking => {
                // Process engine logic
                // If the engine has made a move, transition to ProcessingMove
            },
            .ProcessingMove => {
                // Apply the move to the game state
                // Transition back to AwaitingInput or GameOver if the game ends
            },
            .HoveringPiece => {},
            .GameOver => {
                // Handle game over logic, reset or end the game
            },
        }
    }

    pub fn undoLastMove(self: *GameController) void {
        std.log.info("Undoing last move", .{});
        const lastMove = self.board.lastMoves.pop();
        if (lastMove) |move| {
            self.board.undoMove(move);
            self.moveGen.update(self.board);
            std.log.info("Last move undone: {s}", .{move.getMoveName()});
        } else {
            std.log.warn("No moves to undo", .{});
        }
    }

    pub fn onSquareClick(self: *GameController, square: u6) void {
        std.log.info("Handling square click for square: {}", .{square});

        if (self.selectedSquare.isSelected) {
            if (self.selectedSquare.square == square) {
                self.selectedSquare.clear();
                return;
            }

            for (self.moveGen.pseudoLegalMoves.items) |move| {
                if (move.from == self.selectedSquare.square and move.to == square) {
                    self.board.makeMove(move);

                    if (core.utils.check.isKingInCheck(self.board, self.board.pieceToMove.opposite())) {
                        self.board.undoMove(move);
                    } else {
                        std.debug.print("Move made: {s}\n", .{move.getMoveName()});
                    }

                    self.moveGen.update(self.board);

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
