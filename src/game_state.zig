const std = @import("std");
const b = @import("board.zig");
const r = @import("render.zig");
const pc = @import("player_controller.zig");
const ec = @import("engine_controller.zig");
const mg = @import("move_gen.zig");

const Render = r.Render;
const Board = b.Board;
const PlayerController = pc.PlayerController;
const EngineController = ec.EngineController;
const MoveGen = mg.MoveGen;

pub const GameState = struct {
    // render: *Render,
    board: *Board,
    // player: *PlayerController,
    engine: *EngineController,
    // showSquareNumbers: bool = false,
    // showAttackedSquares: bool = false,

    pub fn init() GameState {
        // const render = std.heap.c_allocator.create(Render) catch std.debug.panic("Failed to allocate Render", .{});
        // render.* = Render.init();

        const board = std.heap.c_allocator.create(Board) catch std.debug.panic("Failed to allocate Board", .{});
        board.* = GameState.initCustomBoard();

        // const player = std.heap.c_allocator.create(PlayerController) catch std.debug.panic("Failed to allocate PlayerController", .{});
        // player.* = PlayerController.init(board, render);

        const engine = std.heap.c_allocator.create(EngineController) catch std.debug.panic("Failed to allocate EngineController", .{});
        engine.* = EngineController.init(board);

        return GameState{
            .render = render,
            .board = board,
            .player = player,
            .engine = engine,
        };
    }

    pub fn deinit(self: *GameState) void {
        // self.render.deinit();
        self.board.deinit();
        // self.player.deinit();
        self.engine.deinit();
        // std.heap.c_allocator.destroy(self.render);
        std.heap.c_allocator.destroy(self.board);
        // std.heap.c_allocator.destroy(self.player);
        std.heap.c_allocator.destroy(self.engine);
    }

    pub fn initCustomBoard() Board {
        return Board.initFromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
        // return Board.initFromFEN("8/8/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
        // return Board.initFromFEN("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1");
        // return Board.initFromFEN("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1");
        // return Board.initFromFEN("r3k2r/7p/8/8/8/8/7P/R3K2R w KQkq - 0 1");
        // return Board.initFromFEN("8/1r6/5r2/8/8/5R2/1R6/8 b KQkq - 0 1");
        // return Board.initFromFEN("8/8/2r2r2/8/8/2R2R2/8/8 b KQkq - 0 1");
        // return Board.initFromFEN("8/8/2b2b2/8/8/2B2B2/8/8 b KQkq - 0 1");
        // return Board.initFromFEN("8/8/2b2b2/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1");

        // Perft Custom Positions
        // return Board.initFromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1");
        // return Board.initFromFEN("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
        // return Board.initFromFEN("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
        // return Board.initFromFEN("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1");
    }
};
