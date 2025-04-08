const std = @import("std");
const rl = @import("raylib");
const Board = @import("board.zig").Board;
const p = @import("piece.zig");
const SoundType = @import("sound.zig").SoundType;
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

const GameState = struct {
    board: Board = undefined,

    pub fn init() GameState {
        var board = Board.init();
        board.moveCount = 10;
        return GameState{
            .board = board,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.board.deinit();
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
