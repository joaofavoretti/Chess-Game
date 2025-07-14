const std = @import("std");
const core = @import("core");
const view = @import("view.zig");
const colors = @import("colors.zig");
const rl = @import("raylib");
const controller = @import("controller");
const time = std.time;

const IVector2 = core.types.IVector2;
const PieceType = core.types.PieceType;
const PieceTypeLength = core.types.PieceTypeLength;
const PieceColor = core.types.PieceColor;
const PieceColorLength = core.types.PieceColorLength;
const Piece = core.types.Piece;
const Bitboard = core.types.Bitboard;
const Board = core.Board;
const MoveCode = core.types.MoveCode;
const MoveProps = core.types.MoveProps;
const Move = core.types.Move;
const Render = view.Render;
const SelectedSquare = core.types.SelectedSquare;
const GameController = controller.GameController;
const GameState = controller.GameState;

const SCREEN_WIDTH = 960;
const SCREEN_HEIGHT = 720;

pub const Interface = struct {
    board: Board,
    showSquareNumbers: bool = false,
    showAllPossibleMoves: bool = false,
    showPiecePossibleMoves: bool = true,

    // Variables defined under setup
    gameController: GameController = undefined,
    render: Render = undefined,

    pub fn init() Interface {
        return Interface{
            .board = Board.init(),
        };
    }

    pub fn deinit(self: *Interface) void {
        self.board.deinit();
        self.render.deinit();
        self.gameController.deinit();
    }

    fn setup(self: *Interface) void {
        self.render = Render.init();
        self.gameController = GameController.init(&self.board);
        self.gameController.setup();
    }

    fn update(self: *Interface, deltaTime: f32) void {
        self.gameController.update(deltaTime);

        if (rl.isKeyPressed(rl.KeyboardKey.f1)) {
            self.showSquareNumbers = !self.showSquareNumbers;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.f2)) {
            self.showAllPossibleMoves = !self.showAllPossibleMoves;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.f3)) {
            self.showPiecePossibleMoves = !self.showPiecePossibleMoves;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.f4)) {
            self.render.inverted = !self.render.inverted;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.u)) {
            self.gameController.undoLastMove();
        }

        if (rl.isMouseButtonPressed(rl.MouseButton.left) and self.render.isMouseOverBoard()) {
            const pos = self.render.getMousePosition();
            const square = self.render.getSquareFromPos(pos);
            self.gameController.onSquareClick(square);
        }
    }

    fn draw(self: *Interface) void {
        rl.clearBackground(colors.INTERFACE_BACKGROUND);
        self.render.drawBoard();

        // TODO: Change this == PlayerThinking interface
        if (self.gameController.state == GameState.PlayerThinking and self.gameController.playerHandler.selectedSquare.isSelected) {
            self.render.highlightTile(self.gameController.playerHandler.selectedSquare.square);
        }

        if (core.utils.check.isKingInCheck(&self.board, self.board.pieceToMove)) {
            const kingSquare = core.utils.check.getKingSquare(&self.board, self.board.pieceToMove);
            self.render.highlightTileColor(
                kingSquare,
                colors.HIGHLIGHT_CHECK,
            );
        }

        self.render.drawPieces(&self.board);

        if (self.showSquareNumbers) {
            self.render.drawSquareNumbers();
        }

        if (self.showAllPossibleMoves) {
            self.render.drawPossibleMoves(&self.gameController.engine.moveGen.pseudoLegalMoves);
        }

        if (self.showPiecePossibleMoves and self.gameController.playerHandler.selectedSquare.isSelected) {
            self.render.drawPossibleMovesFromSquare(
                &self.gameController.engine.moveGen.pseudoLegalMoves,
                self.gameController.playerHandler.selectedSquare.square,
            );
        }
    }

    pub fn run(self: *Interface) void {
        rl.setConfigFlags(rl.ConfigFlags{
            .msaa_4x_hint = true,
        });
        rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Chess");
        defer rl.closeWindow();
        rl.initAudioDevice();
        defer rl.closeAudioDevice();

        rl.setTargetFPS(60);

        self.setup();
        defer self.deinit();

        while (!rl.windowShouldClose()) {
            const deltaTime: f32 = rl.getFrameTime();
            self.update(deltaTime);

            rl.beginDrawing();
            self.draw();
            rl.endDrawing();
        }
    }
};

comptime {
    _ = @import("test.zig");
}
