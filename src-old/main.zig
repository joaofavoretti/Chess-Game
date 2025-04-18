const std = @import("std");
const rl = @import("raylib");
const Board = @import("board.zig").Board;
const eng = @import("engine.zig");
const p = @import("piece.zig");
const SoundType = @import("sound.zig").SoundType;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;
const BaseEngine = eng.BaseEngine;
const RandomEngine = eng.RandomEngine;

const TIME_PER_MOVE = 0.3;

const GameState = struct {
    board: *Board,
    engine: *BaseEngine,
    timeForMove: f32 = 0.0,

    pub fn init() GameState {
        var board = std.heap.c_allocator.create(Board) catch std.debug.panic("Failed to allocate Board", .{});
        board.* = Board.init();

        const engine = std.heap.c_allocator.create(BaseEngine) catch std.debug.panic("Failed to allocate Engine", .{});
        engine.* = RandomEngine.init(board);

        board.moveCount = 10;

        return GameState{
            .board = board,
            .engine = engine,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.board.deinit();
        std.heap.c_allocator.destroy(self.board);

        RandomEngine.deinit(self.engine);
        std.heap.c_allocator.destroy(self.engine);
    }
};

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();
    state.board.playSound(SoundType.GameStart);

    // Count all possible moves
    std.io.getStdOut().writer().print("countPossibleMoves(1): {}\n", .{state.board.countPossibleMoves(1)}) catch std.debug.panic("Failed to print", .{});
    std.io.getStdOut().writer().print("countPossibleMoves(2): {}\n", .{state.board.countPossibleMoves(2)}) catch std.debug.panic("Failed to print", .{});
    std.io.getStdOut().writer().print("countPossibleMoves(3): {}\n", .{state.board.countPossibleMoves(3)}) catch std.debug.panic("Failed to print", .{});
    std.io.getStdOut().writer().print("countPossibleMoves(4): {}\n", .{state.board.countPossibleMoves(4)}) catch std.debug.panic("Failed to print", .{});

    // std.log.info("countPossibleMoves(3): {}\n", .{state.board.countPossibleMoves(3)});
}

fn destroy() void {
    state.deinit();
}

fn update(deltaTime: f32) void {
    state.board.update(deltaTime);

    // state.timeForMove += deltaTime;
    // if (state.timeForMove >= TIME_PER_MOVE) {
    //     state.timeForMove = 0.0;
    //     state.engine.makeMove();
    // }
}

fn draw() void {
    rl.clearBackground(rl.Color.init(48, 46, 43, 255));
    state.board.draw();
}

pub fn main() !void {
    const screenWidth = 960;
    const screenHeight = 720;

    rl.setConfigFlags(rl.ConfigFlags{
        .msaa_4x_hint = true,
    });
    rl.initWindow(screenWidth, screenHeight, "Chess");
    defer rl.closeWindow();
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);

    setup();
    defer destroy();

    while (!rl.windowShouldClose()) {
        const deltaTime: f32 = rl.getFrameTime();
        update(deltaTime);

        rl.beginDrawing();
        draw();
        rl.endDrawing();
    }
}
