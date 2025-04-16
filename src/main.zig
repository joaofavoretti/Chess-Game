const std = @import("std");
const rl = @import("raylib");
const ivec = @import("ivector.zig");

const IVector2 = ivec.IVector2;
const IVector2Eq = ivec.IVector2Eq;

const PieceType = enum {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
};
const PieceTypeLength = @typeInfo(PieceType).@"enum".fields.len;

const PieceColor = enum {
    White,
    Black,
};
const PieceColorLength = @typeInfo(PieceColor).@"enum".fields.len;

const Piece = packed struct(u8) {
    color: u1 = 0,
    pieceType: u3 = 0,
    valid: bool = true,
    _padding: u3 = 0,

    pub fn init(color: PieceColor, pieceType: PieceType) Piece {
        return Piece{
            .color = @intFromEnum(color),
            .pieceType = @intFromEnum(pieceType),
        };
    }

    pub fn initInvalid() Piece {
        return Piece{
            .color = 0,
            .pieceType = 0,
            .valid = false,
            ._padding = 0,
        };
    }

    pub fn getColor(self: *Piece) PieceColor {
        return @enumFromInt(self.color);
    }

    pub fn getPieceType(self: *Piece) PieceType {
        return @enumFromInt(self.pieceType);
    }
};

const Bitboard = u64;

const Board = struct {
    boards: [PieceColorLength][PieceTypeLength]Bitboard,
    pieceToMove: PieceColor,
    castlingRights: u8,
    enPassantTarget: u8,
    halfMoveClock: u8,
    fullMoveNumber: u8,

    fn setBitboard(self: *Board, color: PieceColor, piece: PieceType, bitboard: Bitboard) void {
        self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] = bitboard;
    }

    fn setPiece(self: *Board, color: PieceColor, piece: PieceType, square: u6) void {
        const one: u64 = 1;
        const bitboard = one << square;
        self.setBitboard(color, piece, self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] | bitboard);
    }

    fn clearPiece(self: *Board, color: PieceColor, piece: PieceType, square: u6) void {
        const one: u64 = 1;
        const bitboard = one << square;
        self.setBitboard(color, piece, self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))] & ~bitboard);
    }

    fn initFromFEN(fen: []const u8) Board {
        var tokenizer = std.mem.tokenizeAny(u8, fen, " ");
        const piecePlacement = tokenizer.next() orelse @panic("Invalid FEN: missing piece placement");
        const activeColor = tokenizer.next() orelse @panic("Invalid FEN: missing active color");
        const castlingRights = tokenizer.next() orelse @panic("Invalid FEN: missing castling rights");
        const enPassant = tokenizer.next() orelse @panic("Invalid FEN: missing en passant target");
        const halfMoveClock = tokenizer.next() orelse @panic("Invalid FEN: missing halfmove clock");
        const fullMoveNumber = tokenizer.next() orelse @panic("Invalid FEN: missing fullmove number");

        var board = Board{
            .boards = std.mem.zeroes([PieceColorLength][PieceTypeLength]Bitboard),
            .pieceToMove = if (activeColor[0] == 'w') PieceColor.White else PieceColor.Black,
            .castlingRights = 0,
            .enPassantTarget = if (enPassant[0] == '-') 0 else parseSquare(enPassant),
            .halfMoveClock = std.fmt.parseUnsigned(u8, halfMoveClock, 10) catch @panic("Invalid halfmove clock"),
            .fullMoveNumber = std.fmt.parseUnsigned(u8, fullMoveNumber, 10) catch @panic("Invalid fullmove number"),
        };

        // Parse piece placement
        var rank: u8 = 7;
        var file: u8 = 0;
        for (piecePlacement) |c| {
            if (c == '/') {
                rank -= 1;
                file = 0;
            } else if (c >= '1' and c <= '8') {
                file += c - '0';
            } else {
                const color = if (std.ascii.isUpper(c)) PieceColor.White else PieceColor.Black;
                const piece = switch (std.ascii.toLower(c)) {
                    'p' => PieceType.Pawn,
                    'n' => PieceType.Knight,
                    'b' => PieceType.Bishop,
                    'r' => PieceType.Rook,
                    'q' => PieceType.Queen,
                    'k' => PieceType.King,
                    else => @panic("Invalid piece character"),
                };
                const square = @as(u6, @intCast(rank * 8 + file));
                board.setPiece(color, piece, square);
                file += 1;
            }
        }

        // Parse castling rights
        for (castlingRights) |c| {
            switch (c) {
                'K' => board.castlingRights |= 0b0001,
                'Q' => board.castlingRights |= 0b0010,
                'k' => board.castlingRights |= 0b0100,
                'q' => board.castlingRights |= 0b1000,
                '-' => {},
                else => @panic("Invalid castling rights"),
            }
        }

        return board;
    }

    pub fn parseSquare(square: []const u8) u8 {
        if (square.len != 2) @panic("Invalid square format");
        const file = square[0] - 'a';
        const rank = square[1] - '1';
        return rank * 8 + file;
    }

    pub fn getPieceChar(self: *Board, square: u6) u8 {
        for (0..PieceColorLength) |c| {
            const color: PieceColor = @enumFromInt(c);
            for (0..PieceTypeLength) |p| {
                const piece: PieceType = @enumFromInt(p);
                const bitboard = self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))];
                if ((bitboard >> square) & 1 == 1) {
                    return switch (piece) {
                        PieceType.Pawn => if (color == PieceColor.White) 'P' else 'p',
                        PieceType.Knight => if (color == PieceColor.White) 'N' else 'n',
                        PieceType.Bishop => if (color == PieceColor.White) 'B' else 'b',
                        PieceType.Rook => if (color == PieceColor.White) 'R' else 'r',
                        PieceType.Queen => if (color == PieceColor.White) 'Q' else 'q',
                        PieceType.King => if (color == PieceColor.White) 'K' else 'k',
                    };
                }
            }
        }
        return 0;
    }

    pub fn getPiece(self: *Board, square: u6) Piece {
        for (0..PieceColorLength) |c| {
            const color: PieceColor = @enumFromInt(c);
            for (0..PieceTypeLength) |p| {
                const piece: PieceType = @enumFromInt(p);
                const bitboard = self.boards[@as(usize, @intFromEnum(color))][@as(usize, @intFromEnum(piece))];
                if ((bitboard >> square) & 1 == 1) {
                    return Piece.init(color, piece);
                }
            }
        }
        return Piece.initInvalid();
    }
};

const TEXTURE_ASSET_PATH = "./assets/pieces/default";
const TEXTURE_DEFAULT_PATH = TEXTURE_ASSET_PATH ++ "/Default.png";

const Render = struct {
    WHITE_TILE_COLOR: rl.Color = rl.Color.init(235, 236, 208, 255),
    BLACK_TILE_COLOR: rl.Color = rl.Color.init(115, 149, 82, 255),
    ACTIVE_WHITE_TILE_COLOR: rl.Color = rl.Color.init(245, 246, 130, 255),
    ACTIVE_BLACK_TILE_COLOR: rl.Color = rl.Color.init(185, 202, 67, 255),
    POSSIBLE_MOVE_COLOR: rl.Color = rl.Color.init(0, 0, 0, 30),

    textures: [PieceColorLength][PieceTypeLength]rl.Texture2D,
    tileSize: i32,
    offset: IVector2,
    inverted: bool = false,

    fn getTextureFromPiece(pieceColor: PieceColor, pieceType: PieceType) !rl.Texture2D {
        var buf: std.BoundedArray(u8, 128) = .{};
        try buf.writer().print("{s}/{s}-{s}.png", .{ TEXTURE_ASSET_PATH, @tagName(pieceType), @tagName(pieceColor) });
        try buf.append(0);
        return rl.loadTexture(@ptrCast(buf.constSlice()));
    }

    fn getTexture(pieceColor: PieceColor, pieceType: PieceType) rl.Texture2D {
        const texture = Render.getTextureFromPiece(pieceColor, pieceType) catch rl.loadTexture(TEXTURE_DEFAULT_PATH) catch unreachable;
        rl.setTextureFilter(texture, rl.TextureFilter.bilinear);
        return texture;
    }

    pub fn init() Render {
        const screenWidth = @as(i32, @intCast(rl.getScreenWidth()));
        const screenHeight = @as(i32, @intCast(rl.getScreenHeight()));
        const tileSize = @divTrunc(@min(screenWidth, screenHeight), 8);
        const offsetX = @divTrunc((screenWidth - tileSize * 8), 2);
        const offsetY = @divTrunc((screenHeight - tileSize * 8), 2);
        var textures: [PieceColorLength][PieceTypeLength]rl.Texture2D = undefined;

        for (0..PieceColorLength) |color| {
            for (0..PieceTypeLength) |piece| {
                const pieceColor: PieceColor = @enumFromInt(color);
                const pieceType: PieceType = @enumFromInt(piece);
                textures[color][piece] = Render.getTexture(pieceColor, pieceType);
            }
        }

        return Render{
            .textures = textures,
            .tileSize = tileSize,
            .offset = IVector2.init(offsetX, offsetY),
        };
    }

    pub fn deinit(self: *Render) void {
        for (0..PieceColorLength) |color| {
            for (0..PieceTypeLength) |piece| {
                rl.unloadTexture(self.textures[color][piece]);
            }
        }
    }

    fn isWhiteTile(self: *Render, square: u6) bool {
        const pos = self.getPosFromSquare(square);
        return (@mod((pos.x + pos.y), 2) == 0);
    }

    pub fn getPosFromSquare(self: *Render, square: u6) IVector2 {
        var pos = IVector2.init(square % 8, square / 8);
        if (!self.inverted) {
            pos.x = (7 - pos.x);
        }

        if (self.inverted) {
            pos.y = (7 - pos.y);
        }

        return pos;
    }

    pub fn getSquareFromPos(self: *Render, pos: IVector2) u6 {
        if (pos.x >= 8 or pos.y >= 8) {
            return 0;
        }

        var x = (7 - pos.x);
        var y = pos.y;

        if (self.inverted) {
            x = pos.x;
            y = (7 - pos.y);
        }

        return @intCast(y * 8 + x);
    }

    pub fn drawBoard(self: *Render) void {
        for (0..8) |i| {
            const i_ = @as(i32, @intCast(i));
            for (0..8) |j| {
                const j_ = @as(i32, @intCast(j));
                const x = self.offset.x + i_ * self.tileSize;
                const y = self.offset.y + j_ * self.tileSize;

                var color = self.BLACK_TILE_COLOR;

                const square = @as(u6, @intCast(j_ * 8 + i_));
                if (self.isWhiteTile(square)) {
                    color = self.WHITE_TILE_COLOR;
                }

                rl.drawRectangle(
                    x,
                    y,
                    self.tileSize,
                    self.tileSize,
                    color,
                );
            }
        }
    }

    pub fn drawSquareNumbers(self: *Render) void {
        for (0..8) |i| {
            for (0..8) |j| {
                const square = @as(u6, @intCast(j * 8 + i));

                const pos = self.getPosFromSquare(square);

                const x = self.offset.x + pos.x * self.tileSize;
                const y = self.offset.y + pos.y * self.tileSize;

                var buf: [20]u8 = .{0} ** 20;
                _ = std.fmt.bufPrint(&buf, "{}", .{square}) catch std.debug.panic("Failed to format square number", .{});
                const squareNumber: [:0]const u8 = @ptrCast(&buf);

                const color = if (self.isWhiteTile(square)) rl.Color.white else rl.Color.black;
                rl.drawText(
                    squareNumber,
                    x + 5,
                    y + self.tileSize - 20 - 5,
                    20,
                    color,
                );
            }
        }
    }

    fn highlightTile(self: *Render, square: u6) void {
        const pos = self.getPosFromSquare(square);

        const color = if (self.isWhiteTile(square)) self.ACTIVE_BLACK_TILE_COLOR else self.ACTIVE_WHITE_TILE_COLOR;

        const x = self.offset.x + pos.x * self.tileSize;
        const y = self.offset.y + pos.y * self.tileSize;

        rl.drawRectangle(
            x,
            y,
            self.tileSize,
            self.tileSize,
            color,
        );
    }

    fn drawPiece(self: *Render, pieceColor: PieceColor, pieceType: PieceType, square: u6) void {
        const pos = self.getPosFromSquare(square);

        const x = self.offset.x + pos.x * self.tileSize;
        const y = self.offset.y + pos.y * self.tileSize;

        const dest = rl.Rectangle.init(
            @as(f32, @floatFromInt(x)),
            @as(f32, @floatFromInt(y)),
            @as(f32, @floatFromInt(self.tileSize)),
            @as(f32, @floatFromInt(self.tileSize)),
        );

        const texture = self.textures[@as(usize, @intFromEnum(pieceColor))][@as(usize, @intFromEnum(pieceType))];

        const tWidth = @as(f32, @floatFromInt(texture.width));
        const tHeight = @as(f32, @floatFromInt(texture.height));
        const source = rl.Rectangle.init(0, 0, tWidth, tHeight);
        const origin = rl.Vector2.init(0, 0);

        rl.drawTexturePro(texture, source, dest, origin, 0.0, rl.Color.white);
    }

    fn countTrailingZeros(x: u64) u6 {
        var count: u6 = 0;
        var x_ = x;
        while (x_ != 0) {
            if ((x_ & 1) == 1) break;
            count += 1;
            x_ >>= 1;
        }
        return count;
    }

    pub fn drawPieces(self: *Render, board: *Board) void {
        for (0..PieceColorLength) |color| {
            for (0..PieceTypeLength) |piece| {
                const pieceColor: PieceColor = @enumFromInt(color);
                const pieceType: PieceType = @enumFromInt(piece);
                var bitboard = board.boards[color][piece];
                const one: u64 = 1;

                while (bitboard != 0) {
                    const square = Render.countTrailingZeros(bitboard);
                    self.drawPiece(pieceColor, pieceType, square);
                    bitboard &= ~(one << square);
                }
            }
        }
    }

    pub fn print(board: *Board) void {
        std.debug.print("Board:\n", .{});

        for (0..8) |rank| {
            for (0..8) |file| {
                const square = @as(u6, @intCast(rank * 8 + file));
                const piece = board.getPieceChar(square);
                if (piece != 0) {
                    std.debug.print("{c} ", .{piece});
                } else {
                    std.debug.print(". ", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};

const Controller = struct {
    tileSize: i32,
    offset: IVector2,
    selectedSquare: u6 = 0,
    isSelecting: bool = false,

    pub fn init(baseRender: *Render) Controller {
        return Controller{
            .tileSize = baseRender.tileSize,
            .offset = baseRender.offset,
        };
    }

    pub fn update(self: *Controller, render: *Render, board: *Board) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            if (self.isMouseOverBoard()) {
                std.log.info("Selecting square", .{});
                const pos = self.getMousePosition();
                const square = render.getSquareFromPos(pos);

                if (square != self.selectedSquare and self.isSelecting) {
                    self.movePiece(board, self.selectedSquare, square);
                    self.selectedSquare = square;
                }

                self.isSelecting = true;
                if (square == self.selectedSquare and self.isSelecting) {
                    self.isSelecting = false;
                }

                self.selectedSquare = square;
            }
        }
    }

    fn isMouseOverBoard(self: *Controller) bool {
        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        return (mousePos.x >= self.offset.x and
            mousePos.x < self.offset.x + self.tileSize * 8 and
            mousePos.y >= self.offset.y and
            mousePos.y < self.offset.y + self.tileSize * 8);
    }

    fn getMousePosition(self: *Controller) IVector2 {
        if (!self.isMouseOverBoard()) {
            return IVector2.init(0, 0);
        }

        const mousePos = IVector2.fromVector2(rl.getMousePosition());
        const x = @as(u6, @intCast(@divFloor(mousePos.x - self.offset.x, self.tileSize)));
        const y = @as(u6, @intCast(@divFloor(mousePos.y - self.offset.y, self.tileSize)));
        return IVector2.init(x, y);
    }

    pub fn movePiece(self: *Controller, board: *Board, from: u6, to: u6) void {
        _ = self;
        var piece = board.getPiece(from);
        if (piece.valid) {
            board.clearPiece(piece.getColor(), piece.getPieceType(), from);
            board.setPiece(piece.getColor(), piece.getPieceType(), to);
        }
    }
};

const GameState = struct {
    render: *Render,
    board: *Board,
    controller: *Controller,

    pub fn init() GameState {
        const render = std.heap.c_allocator.create(Render) catch std.debug.panic("Failed to allocate Render", .{});
        render.* = Render.init();

        const board = std.heap.c_allocator.create(Board) catch std.debug.panic("Failed to allocate Board", .{});
        board.* = Board.initFromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

        const controller = std.heap.c_allocator.create(Controller) catch std.debug.panic("Failed to allocate Controller", .{});
        controller.* = Controller.init(render);

        return GameState{
            .render = render,
            .board = board,
            .controller = controller,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.render.deinit();
        std.heap.c_allocator.destroy(self.render);
        std.heap.c_allocator.destroy(self.board);
        std.heap.c_allocator.destroy(self.controller);
    }
};

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();

    state.controller.movePiece(state.board, 8, 16);

    Render.print(state.board);
}

fn destroy() void {
    state.deinit();
}

fn update(deltaTime: f32) void {
    _ = deltaTime;

    if (rl.isKeyPressed(rl.KeyboardKey.r)) {
        state.render.inverted = !state.render.inverted;
    }

    state.controller.update(state.render, state.board);
}

fn draw() void {
    rl.clearBackground(rl.Color.init(48, 46, 43, 255));
    state.render.drawBoard();
    // state.render.drawSquareNumbers();
    if (state.controller.isSelecting) {
        state.render.highlightTile(state.controller.selectedSquare);
    }
    state.render.drawPieces(state.board);
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
