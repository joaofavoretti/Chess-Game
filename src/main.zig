const std = @import("std");
const time = std.time;
const rl = @import("raylib");
const iv = @import("ivector.zig");
const p = @import("piece.zig");
const b = @import("board.zig");
const m = @import("move.zig");
const r = @import("render.zig");
const ss = @import("selected_square.zig");
const pc = @import("player_controller.zig");
const ec = @import("engine_controller.zig");
const gs = @import("game_state.zig");
const mg = @import("move_gen.zig");

const IVector2 = iv.IVector2;

const PieceType = p.PieceType;
const PieceTypeLength = p.PieceTypeLength;
const PieceColor = p.PieceColor;
const PieceColorLength = p.PieceColorLength;
const Piece = p.Piece;

const Bitboard = b.Bitboard;
const Board = b.Board;

const MoveCode = m.MoveCode;
const MoveProps = m.MoveProps;
const Move = m.Move;

const Render = r.Render;

const SelectedSquare = ss.SelectedSquare;

const PlayerController = pc.PlayerController;

const EngineController = ec.EngineController;

const GameState = gs.GameState;

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();

    state.engine.genMoves();
    state.player.genMoves();

    for (1..4) |i| {
        std.debug.print("Perft {}: {}\n", .{ i, state.engine.perft(i) });
    }
    // state.engine.divide(1);
}

fn destroy() void {
    state.deinit();
}

fn update(deltaTime: f32) void {
    if (rl.isKeyPressed(rl.KeyboardKey.r)) {
        state.render.inverted = !state.render.inverted;
    }

    if (rl.isKeyPressed(rl.KeyboardKey.u)) {
        if (state.board.lastMoves.pop()) |lastMove| {
            state.board.undoMove(lastMove);
            state.engine.genMoves();
            state.player.genMoves();
        }
    }

    if (rl.isKeyPressed(rl.KeyboardKey.m)) {
        state.showSquareNumbers = !state.showSquareNumbers;
    }

    if (rl.isKeyPressed(rl.KeyboardKey.a)) {
        state.showAttackedSquares = !state.showAttackedSquares;
    }

    state.player.update(deltaTime);
    state.engine.update(deltaTime);

    if (state.player.madeMove()) {
        state.engine.genMoves();
    }

    if (state.engine.madeMove()) {
        state.player.genMoves();
    }
}

fn draw() void {
    rl.clearBackground(rl.Color.init(48, 46, 43, 255));
    state.render.drawBoard();

    if (state.player.selectedSquare.isSelected) {
        state.render.highlightTile(state.player.selectedSquare.square);
    }

    if (state.board.enPassantTarget) |enPassantTarget| {
        state.render.highlightTile(enPassantTarget);
    }

    // Highlight if the king is in check (still does not work)
    if (mg.isKingInCheck(state.engine.board, state.engine.board.pieceToMove)) {
        const kingSquare = state.board.boards[@intFromEnum(state.board.pieceToMove)][@intFromEnum(PieceType.King)];
        state.render.highlightTileColor(@intCast(@ctz(kingSquare)), rl.Color.red);
    }

    // Highlight all the squares that are attacked (Not optimized on purpose)
    if (state.showAttackedSquares) {
        for (0..64) |square| {
            if (mg.isSquareAttacked(@intCast(square), state.board, state.board.pieceToMove)) {
                state.render.highlightTileColor(@intCast(square), rl.Color.red);
            }
        }
    }

    state.render.drawPieces(state.board);
    state.render.drawPossibleMovesFromList(&state.engine.moveGen.pseudoLegalMoves);

    if (state.showSquareNumbers) {
        state.render.drawSquareNumbers();
    }
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
