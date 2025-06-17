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

const screenWidth = 960;
const screenHeight = 720;

pub const Interface = struct {
    selectedBoard: ?*Board,
    boards: []const *Board,
    state: GameState = undefined,

    pub fn init(boards: []const *Board) Interface {
        if (boards.len == 0) {
            return Interface{
                .selectedBoard = null,
                .boards = boards,
            };
        }

        return Interface{
            .selectedBoard = boards[0],
            .boards = boards,
        };
    }

    fn setup(self: *Interface) void {
        self.state = GameState.init();

        self.state.engine.genMoves();
        self.state.player.genMoves();

        for (1..4) |i| {
            std.debug.print("Perft {}: {}\n", .{ i, self.state.engine.perft(i) });
        }
        // state.engine.divide(1);
    }

    fn destroy(self: *Interface) void {
        for (self.boards) |board| {
            board.deinit();
        }

        self.state.deinit();
    }

    fn update(self: *Interface, deltaTime: f32) void {
        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            self.state.render.inverted = !self.state.render.inverted;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.u)) {
            if (self.state.board.lastMoves.pop()) |lastMove| {
                self.state.board.undoMove(lastMove);
                self.state.engine.genMoves();
                self.state.player.genMoves();
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.m)) {
            self.state.showSquareNumbers = !self.state.showSquareNumbers;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.a)) {
            self.state.showAttackedSquares = !self.state.showAttackedSquares;
        }

        self.state.player.update(deltaTime);
        self.state.engine.update(deltaTime);

        if (self.state.player.madeMove()) {
            self.state.engine.genMoves();
        }

        if (self.state.engine.madeMove()) {
            self.state.player.genMoves();
        }
    }

    fn draw(self: *Interface) void {
        rl.clearBackground(rl.Color.init(48, 46, 43, 255));
        self.state.render.drawBoard();

        if (self.state.player.selectedSquare.isSelected) {
            self.state.render.highlightTile(self.state.player.selectedSquare.square);
        }

        if (self.state.board.enPassantTarget) |enPassantTarget| {
            self.state.render.highlightTile(enPassantTarget);
        }

        // Highlight if the king is in check (still does not work)
        if (mg.isKingInCheck(self.state.engine.board, self.state.engine.board.pieceToMove)) {
            const kingSquare = self.state.board.boards[@intFromEnum(self.state.board.pieceToMove)][@intFromEnum(PieceType.King)];
            self.state.render.highlightTileColor(@intCast(@ctz(kingSquare)), rl.Color.red);
        }

        // Highlight all the squares that are attacked (Not optimized on purpose)
        if (self.state.showAttackedSquares) {
            for (0..64) |square| {
                if (mg.isSquareAttacked(@intCast(square), self.state.board, self.state.board.pieceToMove)) {
                    self.state.render.highlightTileColor(@intCast(square), rl.Color.red);
                }
            }
        }

        self.state.render.drawPieces(self.state.board);
        self.state.render.drawPossibleMovesFromList(&self.state.engine.moveGen.pseudoLegalMoves);

        if (self.state.showSquareNumbers) {
            self.state.render.drawSquareNumbers();
        }
    }

    pub fn run(self: *Interface) void {
        rl.setConfigFlags(rl.ConfigFlags{
            .msaa_4x_hint = true,
        });
        rl.initWindow(screenWidth, screenHeight, "Chess");
        defer rl.closeWindow();
        rl.initAudioDevice();
        defer rl.closeAudioDevice();

        rl.setTargetFPS(60);

        self.setup();
        defer self.destroy();

        while (!rl.windowShouldClose()) {
            const deltaTime: f32 = rl.getFrameTime();
            self.update(deltaTime);

            rl.beginDrawing();
            self.draw();
            rl.endDrawing();
        }
    }
};
