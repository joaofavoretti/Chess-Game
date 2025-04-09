const std = @import("std");
const rl = @import("raylib");
const Board = @import("board.zig").Board;
const Engine = @import("engine.zig").Engine;
const p = @import("piece.zig");
const SoundType = @import("sound.zig").SoundType;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

const TIME_PER_MOVE = 1.0;

const GameState = struct {
    board: *Board,
    engine: *Engine,
    timeForMove: f32 = 0.0,

    pub fn init() GameState {
        var board = std.heap.page_allocator.create(Board) catch std.debug.panic("Failed to allocate Board", .{});
        board.* = Board.init();

        const engine = std.heap.page_allocator.create(Engine) catch std.debug.panic("Failed to allocate Engine", .{});
        engine.* = Engine.init(board);

        board.moveCount = 10;

        std.debug.print("[GameState] Board value of moveCount {}\n", .{board.moveCount});
        std.debug.print("[GameState] Engine value of moveCount {}\n", .{engine.board.moveCount});

        return GameState{
            .board = board,
            .engine = engine,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.board.deinit();
        std.heap.page_allocator.destroy(self.board);

        std.heap.page_allocator.destroy(self.engine);
    }
};

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();
    state.board.playSound(SoundType.GameStart);
}

fn destroy() void {
    state.deinit();
}

fn update(deltaTime: f32) void {
    state.board.update(deltaTime);

    state.engine.makeMove();
}

fn draw() void {
    rl.clearBackground(rl.Color.init(48, 46, 43, 255));
    state.board.draw();
}

pub fn main() !void {
    // const screenWidth = 1024;
    // const screenHeight = 768;
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
