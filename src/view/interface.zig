const std = @import("std");
const core = @import("core");
const view = @import("view.zig");
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

const SCREEN_WIDTH = 960;
const SCREEN_HEIGHT = 720;

pub const Interface = struct {
    board: *Board,
    gameController: GameController,
    render: Render = undefined, // Render is purposely undefined because it is started in the setup function
    showSquareNumbers: bool = false,
    showAttackedSquares: bool = false,

    pub fn init(board: *Board) Interface {
        return Interface{
            .board = board,
            .gameController = GameController.init(board),
        };
    }

    pub fn deinit(self: *Interface) void {
        self.render.deinit();
        self.gameController.deinit();
    }

    fn setup(self: *Interface) void {
        self.render = Render.init();
    }

    fn update(self: *Interface, deltaTime: f32) void {
        self.gameController.update(deltaTime);

        if (rl.isKeyPressed(rl.KeyboardKey.f1)) {
            self.showSquareNumbers = !self.showSquareNumbers;
        }
    }

    fn draw(self: *Interface) void {
        rl.clearBackground(rl.Color.init(48, 46, 43, 255));
        self.render.drawBoard();

        self.render.drawPieces(self.board);

        if (self.showSquareNumbers) {
            self.render.drawSquareNumbers();
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
