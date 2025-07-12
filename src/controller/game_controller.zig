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
    state: GameState = .AwaitingInput,

    pub fn init(board: *core.Board) GameController {
        return GameController{
            .board = board,
        };
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

    fn onSquareClick(self: *GameController, square: core.types.IVector2) void {
        _ = self;
        _ = square;
        // Handle square click events
        // This could involve selecting a piece, moving a piece, etc.
    }

    pub fn deinit(self: *GameController) void {
        _ = self;

        // Cleanup resources if necessary
    }
};
