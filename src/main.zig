const std = @import("std");
const rl = @import("raylib");
const Board = @import("board.zig").Board;
const p = @import("piece.zig");
const Piece = p.Piece;
const PieceColor = p.PieceColor;
const PieceType = p.PieceType;

const GameState = struct {
    board: Board = undefined,

    pub fn init() GameState {
        return GameState{
            .board = Board.init(),
        };
    }

    pub fn deinit(self: *GameState) void {
        self.board.deinit();
    }
};

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();
}

fn destroy() void {
    state.deinit();
}

fn update(deltaTime: f32) void {
    state.board.update(deltaTime);
}

fn draw() void {
    rl.clearBackground(rl.Color.ray_white);
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
