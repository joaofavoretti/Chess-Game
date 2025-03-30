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
};

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();
}

fn update(deltaTime: f32) void {
    state.board.update(deltaTime);
}

fn draw() void {
    rl.clearBackground(rl.Color.ray_white);
    state.board.draw();
}

pub fn main() anyerror!void {
    const screenWidth = 1024;
    const screenHeight = 768;

    rl.initWindow(screenWidth, screenHeight, "Basic Window");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    setup();

    while (!rl.windowShouldClose()) {
        const deltaTime: f32 = rl.getFrameTime();
        update(deltaTime);

        rl.beginDrawing();
        draw();
        rl.endDrawing();
    }
}
