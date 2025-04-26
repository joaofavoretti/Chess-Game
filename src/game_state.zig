const std = @import("std");
const b = @import("board.zig");
const r = @import("render.zig");
const pc = @import("player_controller.zig");

const Render = r.Render;
const Board = b.Board;
const PlayerController = pc.PlayerController;

pub const GameState = struct {
    render: *Render,
    board: *Board,
    controller: *PlayerController,

    pub fn init() GameState {
        const render = std.heap.c_allocator.create(Render) catch std.debug.panic("Failed to allocate Render", .{});
        render.* = Render.init();

        const board = std.heap.c_allocator.create(Board) catch std.debug.panic("Failed to allocate Board", .{});
        board.* = Board.initFromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
        // board.* = Board.initFromFEN("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1");

        const controller = std.heap.c_allocator.create(PlayerController) catch std.debug.panic("Failed to allocate PlayerController", .{});
        controller.* = PlayerController.init(render);

        return GameState{
            .render = render,
            .board = board,
            .controller = controller,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.render.deinit();
        self.board.deinit();
        std.heap.c_allocator.destroy(self.render);
        std.heap.c_allocator.destroy(self.board);
        std.heap.c_allocator.destroy(self.controller);
    }
};
