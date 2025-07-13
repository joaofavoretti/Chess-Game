const std = @import("std");
const core = @import("core");
const engine = @import("engiene");

const GameState = enum {
    AwaitingInput,
    EngineThinking,
    End,
};

const PlayerType = enum {
    Human,
    Engine,
};

// Defines the game player
// 0 - Plays as White (Human)
// 1 - Plays as Black (Engine)
const GamePlayers: [2]PlayerType = .{ .Human, .Engine };

fn GetPlayerType(board: *core.Board) PlayerType {
    const colorToMove = board.pieceToMove;
    return GamePlayers[@intFromEnum(colorToMove)];
}

pub const GameController = struct {
    board: *core.Board,
    state: GameState,
    selectedSquare: core.types.SelectedSquare,
    moveGen: core.MoveGen,
    engine: engine.Engine,

    pub fn init(board: *core.Board) GameController {
        return GameController{
            .board = board,
            .state = if (GetPlayerType(board) == .Human) GameState.AwaitingInput else GameState.EngineThinking,
            .selectedSquare = core.types.SelectedSquare.init(),
            .moveGen = core.MoveGen.init(std.heap.page_allocator),
            .engine = engine.Engine.init(board),
        };
    }

    pub fn setup(self: *GameController) void {
        self.moveGen.update(self.board);
    }

    pub fn deinit(self: *GameController) void {
        self.moveGen.deinit();
    }

    pub fn update(self: *GameController, deltaTime: f32) void {
        _ = deltaTime;
        switch (self.state) {
            .AwaitingInput => {
                return;
            },
            .EngineThinking => {
                const engineMove = self.engine.getMove(self.moveGen.pseudoLegalMoves);
                if (engineMove) |m| {
                    if (self.applyMove(m)) {
                        self.state = GameState.AwaitingInput;
                        std.log.info("Engine made move: {s}", .{m.getMoveName()});
                    } else {
                        std.log.warn("Engine tried to make an illegal move: {s}", .{m.getMoveName()});
                    }
                } else {
                    self.state = GameState.End;
                }
            },
            .End => {
                std.log.info("Game is halted, no updates will be processed", .{});
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

    fn applyMove(self: *GameController, move: *core.types.Move) bool {
        self.board.makeMove(move);

        if (core.utils.check.isKingInCheck(self.board, self.board.pieceToMove.opposite())) {
            self.board.undoMove(move);
        } else {
            std.debug.print("Move made: {s}\n", .{move.getMoveName()});
        }

        self.moveGen.update(self.board);
        self.state = if (GetPlayerType(self.board) == .Human) GameState.AwaitingInput else GameState.EngineThinking;
    }

    pub fn onSquareClick(self: *GameController, square: u6) void {
        std.log.info("Handling square click for square: {}", .{square});

        if (self.state != .AwaitingInput) {
            std.log.warn("Ignoring click, not in AwaitingInput state", .{});
            return;
        }

        if (self.selectedSquare.isSelected) {
            if (self.selectedSquare.square == square) {
                self.selectedSquare.clear();
                return;
            }

            for (self.moveGen.pseudoLegalMoves.items) |move| {
                if (move.from == self.selectedSquare.square and move.to == square) {
                    self.applyMove(move);

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
