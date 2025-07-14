const std = @import("std");
const core = @import("core");
const engine = @import("engine");
const PlayerHandler = @import("player_handler.zig").PlayerHandler;

pub const GameState = enum {
    PlayerThinking,
    EngineThinking,
    End,
};

pub const PlayerType = enum {
    Human,
    Engine,
};

// Defines the game player
// 0 - Plays as White
// 1 - Plays as Black
const GamePlayers: [2]PlayerType = .{ .Engine, .Human };

fn GetPlayerType(board: *core.Board) PlayerType {
    const colorToMove = board.pieceToMove;
    return GamePlayers[@intFromEnum(colorToMove)];
}

pub const GameController = struct {
    board: *core.Board,
    state: GameState,

    // TODO: I dont like both structs having their own moveGen struct instance
    playerHandler: PlayerHandler,
    engine: engine.Engine,

    pub fn init(board: *core.Board) GameController {
        return GameController{
            .board = board,
            .state = if (GetPlayerType(board) == .Human) GameState.PlayerThinking else GameState.EngineThinking,
            .playerHandler = PlayerHandler.init(board),
            .engine = engine.Engine.init(board),
        };
    }

    pub fn setup(self: *GameController) void {
        self.playerHandler.setup();
        self.engine.setup();
    }

    pub fn deinit(self: *GameController) void {
        self.playerHandler.deinit();
        self.engine.deinit();
    }

    pub fn update(self: *GameController, deltaTime: f32) void {
        switch (self.state) {
            .PlayerThinking => {
                self.playerHandler.update(deltaTime);
                if (self.playerHandler.decidedMove()) |move| {
                    if (self.applyMove(move)) {
                        std.log.info("Player made move: {s}", .{move.getMoveName()});
                        self.state = GameState.EngineThinking;
                    } else {
                        std.log.warn("Player tried to make an illegal move: {s}", .{move.getMoveName()});
                    }
                }
            },
            .EngineThinking => {
                const engineMove = self.engine.getMove();
                if (engineMove) |m| {
                    if (self.applyMove(m)) {
                        self.state = GameState.PlayerThinking;
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
            self.onBoardChange();
            std.log.info("Last move undone: {s}", .{move.getMoveName()});
        } else {
            std.log.warn("No moves to undo", .{});
        }
    }

    fn applyMove(self: *GameController, move: core.types.Move) bool {
        self.board.makeMove(move);

        if (core.utils.check.isKingInCheck(self.board, self.board.pieceToMove.opposite())) {
            self.board.undoMove(move);
            return false;
        } else {
            std.debug.print("Move made: {s}\n", .{move.getMoveName()});
        }

        self.onBoardChange();
        self.state = if (GetPlayerType(self.board) == .Human) GameState.PlayerThinking else GameState.EngineThinking;

        return true;
    }

    pub fn onBoardChange(self: *GameController) void {
        std.log.info("Handling board change", .{});
        self.playerHandler.onBoardChange();
        self.engine.onBoardChange();
    }

    pub fn onSquareClick(self: *GameController, square: u6) void {
        std.log.info("Handling square click for square: {}", .{square});

        switch (self.state) {
            .PlayerThinking => {
                self.playerHandler.onSquareClick(square);
            },
            else => {},
        }
    }
};
