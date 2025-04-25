const std = @import("std");
const rl = @import("raylib");
const iv = @import("ivector.zig");

const IVector2 = iv.IVector2;

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

    pub fn oposite(self: PieceColor) PieceColor {
        return if (self == PieceColor.White) PieceColor.Black else PieceColor.White;
    }
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

    pub fn getColor(self: *const Piece) PieceColor {
        return @enumFromInt(self.color);
    }

    pub fn getPieceType(self: *const Piece) PieceType {
        return @enumFromInt(self.pieceType);
    }
};

const Bitboard = u64;

const Board = struct {
    boards: [PieceColorLength][PieceTypeLength]Bitboard,
    pieceToMove: PieceColor,
    castlingRights: u8,
    enPassantTarget: u6,
    halfMoveClock: u8,
    fullMoveNumber: u8,
    lastMoves: std.ArrayList(Move),

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

    fn deinit(self: *Board) void {
        self.lastMoves.deinit();
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
            .lastMoves = std.ArrayList(Move).init(std.heap.c_allocator),
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
                'K' => board.castlingRights |= 0b0001, // White king side
                'Q' => board.castlingRights |= 0b0010, // White queen side
                'k' => board.castlingRights |= 0b0100, // Black king side
                'q' => board.castlingRights |= 0b1000, // Black queen side
                '-' => {},
                else => @panic("Invalid castling rights"),
            }
        }

        return board;
    }

    pub fn parseSquare(square: []const u8) u6 {
        if (square.len != 2) @panic("Invalid square format");
        const file = square[0] - 'a';
        const rank = square[1] - '1';
        return @intCast(rank * 8 + file);
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

const MoveCode = enum(u4) {
    // Bits: Promotion, Capture, Special 1, Special 2
    QuietMove = 0b0000,
    DoublePawnPush = 0b0001,
    KingCastle = 0b0010,
    QueenCastle = 0b0011,
    Capture = 0b0100,
    EnPassant = 0b0101,
    KnightPromotion = 0b1000,
    BishopPromotion = 0b1001,
    RookPromotion = 0b1010,
    QueenPromotion = 0b1011,
    KnightPromotionCapture = 0b1100,
    BishopPromotionCapture = 0b1101,
    RookPromotionCapture = 0b1110,
    QueenPromotionCapture = 0b1111,

    pub fn isCapture(self: MoveCode) bool {
        return (@intFromEnum(self) & 0b0100) != 0;
    }

    pub fn isPromotion(self: MoveCode) bool {
        return (@intFromEnum(self) & 0b1000) != 0;
    }
};

const MoveProps = union(MoveCode) {
    QuietMove: struct {},
    DoublePawnPush: struct {},
    KingCastle: struct {},
    QueenCastle: struct {},
    Capture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    EnPassant: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    KnightPromotion: struct {},
    BishopPromotion: struct {},
    RookPromotion: struct {},
    QueenPromotion: struct {},
    KnightPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    BishopPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    RookPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
    QueenPromotionCapture: struct {
        capturedPiece: Piece = Piece.initInvalid(),
    },
};

pub const Move = struct {
    // Basic move data
    from: u6,
    to: u6,

    // Move type
    props: MoveProps,

    // Board state memory (I still dont know if I should)
    pieceToMove: PieceColor,
    castlingRights: u8,
    enPassantTarget: u6,
    halfMoveClock: u8,
    fullMoveNumber: u8,

    pub fn init(from: u6, to: u6, boardState: *Board, props: MoveProps) Move {
        return Move{
            .from = from,
            .to = to,
            .props = props,
            .pieceToMove = boardState.pieceToMove,
            .castlingRights = boardState.castlingRights,
            .enPassantTarget = boardState.enPassantTarget,
            .halfMoveClock = boardState.halfMoveClock,
            .fullMoveNumber = boardState.fullMoveNumber,
        };
    }

    pub fn isValid(self: *const Move) bool {
        return self.from != self.to;
    }

    pub fn getCode(self: *const Move) MoveCode {
        return @as(MoveCode, self.props);
    }

    pub fn getCapturedPiece(self: *const Move) Piece {
        return switch (self.getCode()) {
            MoveCode.Capture => self.props.Capture.capturedPiece,
            MoveCode.EnPassant => self.props.EnPassant.capturedPiece,
            MoveCode.KnightPromotionCapture => self.props.KnightPromotionCapture.capturedPiece,
            MoveCode.BishopPromotionCapture => self.props.BishopPromotionCapture.capturedPiece,
            MoveCode.RookPromotionCapture => self.props.RookPromotionCapture.capturedPiece,
            MoveCode.QueenPromotionCapture => self.props.QueenPromotionCapture.capturedPiece,
            else => Piece.initInvalid(),
        };
    }

    pub fn getLastCastlingRights(self: *const Move) u8 {
        return switch (self.getCode()) {
            MoveCode.KingCastle => self.props.KingCastle.lastCastlingRights,
            MoveCode.QueenCastle => self.props.QueenCastle.lastCastlingRights,
            else => 0,
        };
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
        return (@mod((pos.x + pos.y), 2) == 1);
    }

    pub fn isPosValid(_: *Render, pos: IVector2) bool {
        return (pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8);
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

    pub fn drawPossibleMoves(self: *Render, controller: *Controller) void {
        const radius = @divTrunc(self.tileSize, 6);
        const padding = @divTrunc(self.tileSize - radius * 2, 2);

        const moves = controller.pseudoLegalMoves.constSlice();

        for (0..moves.len) |i| {
            const move: Move = moves[i];
            const square = move.to;
            const pos = self.getPosFromSquare(square);

            const center = rl.Vector2.init(
                @as(f32, @floatFromInt(self.offset.x + pos.x * self.tileSize + padding + radius)),
                @as(f32, @floatFromInt(self.offset.y + pos.y * self.tileSize + padding + radius)),
            );

            if (move.getCode().isCapture()) {
                const size = @as(f32, @floatFromInt(self.tileSize));
                const rect = rl.Rectangle{
                    .x = @as(f32, @floatFromInt(self.offset.x + pos.x * self.tileSize)) + 6.0,
                    .y = @as(f32, @floatFromInt(self.offset.y + pos.y * self.tileSize)) + 6.0,
                    .width = size - 12.0,
                    .height = size - 12.0,
                };

                rl.drawRectangleRoundedLinesEx(rect, 16.0, 16, 6.0, self.POSSIBLE_MOVE_COLOR);
            } else {
                rl.drawCircleV(center, @as(f32, @floatFromInt(radius)), self.POSSIBLE_MOVE_COLOR);
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

const SelectedSquare = struct {
    square: u6 = 0,
    isSelected: bool = false,

    pub fn init() SelectedSquare {
        return SelectedSquare{
            .square = 0,
            .isSelected = false,
        };
    }

    pub fn setSquare(self: *SelectedSquare, square: u6) void {
        self.square = square;
        self.isSelected = true;
    }

    pub fn clear(self: *SelectedSquare) void {
        self.square = 0;
        self.isSelected = false;
    }
};

const Controller = struct {
    tileSize: i32,
    offset: IVector2,
    selectedSquare: SelectedSquare = SelectedSquare.init(),
    pseudoLegalMoves: std.BoundedArray(Move, 64) = .{},

    pub fn init(baseRender: *Render) Controller {
        return Controller{
            .tileSize = baseRender.tileSize,
            .offset = baseRender.offset,
        };
    }

    fn updatePawnMoves(self: *Controller, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();
        var direction: i32 = if (color == PieceColor.White) 1 else -1;

        if (render.inverted) direction *= -1;

        // Capture diagonally
        for (0..2) |i| {
            const i_ = @as(i32, @intCast(i));
            const targetPos = iv.IVector2Add(pos, IVector2.init(i_ * 2 - 1, direction));
            if (!render.isPosValid(targetPos)) {
                continue;
            }
            const targetSquare = render.getSquareFromPos(targetPos);
            var targetPiece = board.getPiece(targetSquare);

            // Regular diagonal capture
            if (targetPiece.valid and targetPiece.getColor() != color) {
                const finalFile: i32 = if (color == PieceColor.White) 7 else 0;
                const isFinalPosition = (targetSquare / 8) == finalFile;
                if (isFinalPosition) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QueenPromotionCapture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .Capture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                }
            }

            // En passant capture
            if (targetSquare == board.enPassantTarget) {
                if (board.lastMoves.getLastOrNull()) |lastMove| {
                    var lastMovePiece = board.getPiece(lastMove.to);
                    if (lastMovePiece.valid and lastMovePiece.getColor() != color and lastMove.getCode() == MoveCode.DoublePawnPush) {
                        self.pseudoLegalMoves.append(Move.init(
                            self.selectedSquare.square,
                            targetSquare,
                            board,
                            .{ .EnPassant = .{ .capturedPiece = lastMovePiece } },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                }
            }
        }

        // Move forward
        const forwardPos = iv.IVector2Add(pos, IVector2.init(0, direction));
        if (!render.isPosValid(forwardPos)) {
            return;
        }
        const forwardSquare = render.getSquareFromPos(forwardPos);
        const forwardPiece = board.getPiece(forwardSquare);
        if (!forwardPiece.valid) {
            const finalFile: i32 = if (color == PieceColor.White) 7 else 0;
            const isFinalPosition = (forwardSquare / 8) == finalFile;
            if (isFinalPosition) {
                self.pseudoLegalMoves.append(Move.init(
                    self.selectedSquare.square,
                    forwardSquare,
                    board,
                    .{ .QueenPromotion = .{} },
                )) catch std.debug.panic("Failed to append move", .{});
                return;
            } else {
                self.pseudoLegalMoves.append(Move.init(
                    self.selectedSquare.square,
                    forwardSquare,
                    board,
                    .{ .QuietMove = .{} },
                )) catch std.debug.panic("Failed to append move", .{});
            }

            // Double pawn push
            const doubleForwardPos = iv.IVector2Add(forwardPos, IVector2.init(0, direction));
            if (!render.isPosValid(doubleForwardPos)) {
                return;
            }
            const doubleForwardSquare = render.getSquareFromPos(doubleForwardPos);
            const doubleForwardPiece = board.getPiece(doubleForwardSquare);
            const initialFile: i32 = if (color == PieceColor.White) 1 else 6;
            const isInitialPosition = (self.selectedSquare.square / 8) == initialFile;
            if (!doubleForwardPiece.valid and isInitialPosition) {
                self.pseudoLegalMoves.append(Move.init(
                    self.selectedSquare.square,
                    doubleForwardSquare,
                    board,
                    .{ .DoublePawnPush = .{} },
                )) catch std.debug.panic("Failed to append move", .{});
            }
        }
    }

    fn updateKnightMoves(self: *Controller, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Knight moves
        const knightMoves = [8]IVector2{
            IVector2.init(1, 2),
            IVector2.init(2, 1),
            IVector2.init(2, -1),
            IVector2.init(1, -2),
            IVector2.init(-1, -2),
            IVector2.init(-2, -1),
            IVector2.init(-2, 1),
            IVector2.init(-1, 2),
        };

        for (0..8) |i| {
            const move = knightMoves[i];
            const targetPos = iv.IVector2Add(pos, move);

            if (render.isPosValid(targetPos)) {
                const targetSquare = render.getSquareFromPos(targetPos);
                var targetPiece = board.getPiece(targetSquare);
                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                }

                if (targetPiece.valid and targetPiece.getColor() != color) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .Capture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                }
            }
        }
    }

    fn updateBishopMoves(self: *Controller, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Directions for bishop movement: top-right, top-left, bottom-right, bottom-left
        const directions = [4]IVector2{
            IVector2.init(1, 1),
            IVector2.init(-1, 1),
            IVector2.init(1, -1),
            IVector2.init(-1, -1),
        };

        for (directions) |direction| {
            var currentPos = pos;

            while (true) {
                currentPos = iv.IVector2Add(currentPos, direction);

                if (!render.isPosValid(currentPos)) {
                    break;
                }

                const targetSquare = render.getSquareFromPos(currentPos);
                var targetPiece = board.getPiece(targetSquare);

                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else {
                    if (targetPiece.getColor() != color) {
                        self.pseudoLegalMoves.append(Move.init(
                            self.selectedSquare.square,
                            targetSquare,
                            board,
                            .{ .DoublePawnPush = .{} },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                    break; // Stop moving in this direction after encountering a piece
                }
            }
        }
    }

    fn updateRookMoves(self: *Controller, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Directions for rook movement: up, down, left, right
        const directions = [4]IVector2{
            IVector2.init(0, 1), // Up
            IVector2.init(0, -1), // Down
            IVector2.init(1, 0), // Right
            IVector2.init(-1, 0), // Left
        };

        for (directions) |direction| {
            var currentPos = pos;

            while (true) {
                currentPos = iv.IVector2Add(currentPos, direction);

                if (!render.isPosValid(currentPos)) {
                    break;
                }

                const targetSquare = render.getSquareFromPos(currentPos);
                var targetPiece = board.getPiece(targetSquare);

                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else {
                    if (targetPiece.getColor() != color) {
                        self.pseudoLegalMoves.append(Move.init(
                            self.selectedSquare.square,
                            targetSquare,
                            board,
                            .{ .Capture = .{ .capturedPiece = targetPiece } },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                    break; // Stop moving in this direction after encountering a piece
                }
            }
        }
    }

    fn updateKingMoves(self: *Controller, board: *Board, render: *Render) void {
        var piece = board.getPiece(self.selectedSquare.square);
        const pos = render.getPosFromSquare(self.selectedSquare.square);
        const color = piece.getColor();

        // Direction vectors for king moves.
        const kingMoves = [8]IVector2{
            IVector2.init(1, 0),
            IVector2.init(1, 1),
            IVector2.init(0, 1),
            IVector2.init(-1, 1),
            IVector2.init(-1, 0),
            IVector2.init(-1, -1),
            IVector2.init(0, -1),
            IVector2.init(1, -1),
        };

        // Regular moves
        for (kingMoves) |delta| {
            const targetPos = iv.IVector2Add(pos, delta);
            if (render.isPosValid(targetPos)) {
                const targetSquare = render.getSquareFromPos(targetPos);
                var targetPiece = board.getPiece(targetSquare);
                if (!targetPiece.valid) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .QuietMove = .{} },
                    )) catch std.debug.panic("Failed to append move", .{});
                } else if (targetPiece.getColor() != color) {
                    self.pseudoLegalMoves.append(Move.init(
                        self.selectedSquare.square,
                        targetSquare,
                        board,
                        .{ .Capture = .{ .capturedPiece = targetPiece } },
                    )) catch std.debug.panic("Failed to append move", .{});
                }
            }
        }

        // Castling moves
        const castlingRights = if (color == PieceColor.White) (board.castlingRights & 0b0011) else ((board.castlingRights & 0b1100) >> 2);
        for (0..2) |i| { // 0 = King-side, 1 = Queen-side
            if (castlingRights & (@as(u2, 0b01) << @intCast(i)) != 0) {
                const kingSquare = self.selectedSquare.square;
                const direction: i32 = if (i == 0) 1 else -1;
                const rookSquareDelta: i32 = if (i == 0) 3 else -4;

                var emptySquares = std.BoundedArray(u6, 3){};

                var j: i32 = direction;
                while (j * direction < rookSquareDelta * direction) {
                    emptySquares.append(@intCast(kingSquare + j)) catch std.debug.panic("Failed to append square", .{});
                    j += direction;
                }

                const squares = emptySquares.constSlice();
                for (0..squares.len) |x| {
                    const square = squares[x];
                    if (board.getPiece(square).valid) {
                        break;
                    }
                } else {
                    if (i == 0) {
                        self.pseudoLegalMoves.append(Move.init(
                            kingSquare,
                            @intCast(kingSquare + 2 * direction),
                            board,
                            .{ .KingCastle = .{} },
                        )) catch std.debug.panic("Failed to append move", .{});
                    } else {
                        self.pseudoLegalMoves.append(Move.init(
                            kingSquare,
                            @intCast(kingSquare + 2 * direction),
                            board,
                            .{ .QueenCastle = .{} },
                        )) catch std.debug.panic("Failed to append move", .{});
                    }
                }
            }
        }
    }

    fn updatePseudoLegalMoves(self: *Controller, board: *Board, render: *Render) void {
        // clear the pseudoLegalMoves
        self.pseudoLegalMoves.clear();

        if (self.selectedSquare.isSelected) {
            var piece = board.getPiece(self.selectedSquare.square);

            if (!piece.valid) {
                return;
            }

            if (piece.getColor() != board.pieceToMove) {
                return;
            }

            switch (piece.getPieceType()) {
                PieceType.Pawn => self.updatePawnMoves(board, render),
                PieceType.Knight => self.updateKnightMoves(board, render),
                PieceType.Bishop => self.updateBishopMoves(board, render),
                PieceType.Rook => self.updateRookMoves(board, render),
                PieceType.Queen => {
                    self.updateBishopMoves(board, render);
                    self.updateRookMoves(board, render);
                },
                PieceType.King => self.updateKingMoves(board, render),
            }
        }
    }

    fn makeMove(_: *Controller, board: *Board, move: Move) void {
        var piece = board.getPiece(move.from);

        if (piece.getColor() != board.pieceToMove) {
            return;
        }

        board.fullMoveNumber += if (piece.getColor() == PieceColor.Black) 1 else 0;
        board.halfMoveClock += if (piece.getColor() == PieceColor.White) 1 else 0;

        if (piece.valid) {
            board.clearPiece(piece.getColor(), piece.getPieceType(), move.from);
            board.setPiece(piece.getColor(), piece.getPieceType(), move.to);
        }

        // Disable castling rights if it is a king move
        if (piece.getPieceType() == PieceType.King) {
            board.castlingRights &= if (piece.getColor() == PieceColor.White) 0b1100 else 0b0011;
        }

        // If the moved rook is one of the unused ones for castle, update the castling rights
        if (piece.getPieceType() == PieceType.Rook) {
            const shiftAmount: u2 = if (piece.getColor() == PieceColor.White) 0 else 2;
            const castlingRightsMask = @as(u4, 0b0011) << shiftAmount;
            const opositeCastlingRightsMask = @as(u4, 0b1111) ^ castlingRightsMask;
            var castlingRights = (board.castlingRights & castlingRightsMask) >> shiftAmount;
            if (castlingRights != 0) {
                // The king wast moved
                const kingSquare: u6 = if (piece.getColor() == PieceColor.White) 4 else 60;
                const rookSquares = [2]u6{ kingSquare + 3, kingSquare - 4 };
                for (0..2) |i| { // 0 = King-side, 1 = Queen-side
                    const rookSquare = rookSquares[i];
                    if (move.from == rookSquare) {
                        // Update the castling rights to remove the side of the rook
                        castlingRights &= @as(u4, 0b0001) << @intCast(1 - i);
                        board.castlingRights &= (castlingRights << shiftAmount) | opositeCastlingRightsMask;
                    }
                }
            }
        }

        if (move.getCode().isCapture() or piece.getPieceType() == PieceType.Pawn) {
            board.halfMoveClock = 0;
        }

        // if the captured piece is a rook, I also need to update the castling rights
        if (move.getCode().isCapture() and move.getCapturedPiece().getPieceType() == PieceType.Rook) {
            std.log.info("Captured rook", .{});
            const capturedRook = move.getCapturedPiece();
            const shiftAmount: u2 = if (capturedRook.getColor() == PieceColor.White) 0 else 2;
            const castlingRightsMask = @as(u4, 0b0011) << shiftAmount;
            const opositeCastlingRightsMask = @as(u4, 0b1111) ^ castlingRightsMask;
            var castlingRights = (board.castlingRights & castlingRightsMask) >> shiftAmount;
            if (castlingRights != 0) {
                // The king wast moved
                const kingSquare: u6 = if (capturedRook.getColor() == PieceColor.White) 4 else 60;
                const rookSquares = [2]u6{ kingSquare + 3, kingSquare - 4 };
                for (0..2) |i| { // 0 = King-side, 1 = Queen-side
                    const rookSquare = rookSquares[i];
                    if (move.to == rookSquare) {
                        std.log.info("Updating the castling rights according to the captured rook", .{});
                        // Update the castling rights to remove the side of the rook
                        castlingRights &= @as(u4, 0b0001) << @intCast(1 - i);
                        board.castlingRights &= (castlingRights << shiftAmount) | opositeCastlingRightsMask;
                    }
                }
            }
        }

        if (move.getCode() == MoveCode.DoublePawnPush) {
            const direction: i32 = if (piece.getColor() == PieceColor.White) -1 else 1;
            board.enPassantTarget = @intCast(move.to + direction * 8);
        }

        if (move.getCode().isCapture() and move.getCode() != MoveCode.EnPassant) {
            var capturedPiece = move.getCapturedPiece();
            board.clearPiece(capturedPiece.getColor(), capturedPiece.getPieceType(), move.to);
        }

        if (move.getCode() == MoveCode.EnPassant) {
            const direction: i32 = if (piece.getColor() == PieceColor.White) -1 else 1;
            const targetSquare: u6 = @intCast(move.to + direction * 8);
            var targetPiece = move.getCapturedPiece();
            board.clearPiece(targetPiece.getColor(), targetPiece.getPieceType(), targetSquare);
        }

        if (move.getCode().isPromotion()) {
            const pieceType = switch (move.getCode()) {
                MoveCode.KnightPromotion => PieceType.Knight,
                MoveCode.BishopPromotion => PieceType.Bishop,
                MoveCode.RookPromotion => PieceType.Rook,
                MoveCode.QueenPromotion => PieceType.Queen,
                MoveCode.KnightPromotionCapture => PieceType.Knight,
                MoveCode.BishopPromotionCapture => PieceType.Bishop,
                MoveCode.RookPromotionCapture => PieceType.Rook,
                MoveCode.QueenPromotionCapture => PieceType.Queen,
                else => unreachable,
            };
            board.clearPiece(piece.getColor(), piece.getPieceType(), move.to);
            board.setPiece(piece.getColor(), pieceType, move.to);
        }

        if (move.getCode() == MoveCode.KingCastle) {
            const direction: i32 = 1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 3);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, rookSquare);
        } else if (move.getCode() == MoveCode.QueenCastle) {
            const direction: i32 = -1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 4);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, rookSquare);
        }

        board.pieceToMove = board.pieceToMove.oposite();

        board.lastMoves.append(move) catch std.debug.panic("Failed to append move to lastMoves stack", .{});
    }

    fn undoMove(_: *Controller, board: *Board, move: Move) void {
        var piece = board.getPiece(move.to);

        if (piece.getColor() != board.pieceToMove.oposite()) {
            return;
        }

        if (piece.valid) {
            board.clearPiece(piece.getColor(), piece.getPieceType(), move.to);
            board.setPiece(piece.getColor(), piece.getPieceType(), move.from);
        }

        if (move.getCode().isCapture() and move.getCode() != MoveCode.EnPassant) {
            var capturedPiece = move.getCapturedPiece();
            board.setPiece(capturedPiece.getColor(), capturedPiece.getPieceType(), move.to);
        }

        if (move.getCode() == MoveCode.EnPassant) {
            const direction: i32 = if (piece.getColor() == PieceColor.White) -1 else 1;
            const targetSquare: u6 = @intCast(move.to + direction * 8);
            var targetPiece = move.getCapturedPiece();
            board.setPiece(targetPiece.getColor(), targetPiece.getPieceType(), targetSquare);
        }

        if (move.getCode().isPromotion()) {
            const pieceType = switch (move.getCode()) {
                MoveCode.KnightPromotion => PieceType.Knight,
                MoveCode.BishopPromotion => PieceType.Bishop,
                MoveCode.RookPromotion => PieceType.Rook,
                MoveCode.QueenPromotion => PieceType.Queen,
                MoveCode.KnightPromotionCapture => PieceType.Knight,
                MoveCode.BishopPromotionCapture => PieceType.Bishop,
                MoveCode.RookPromotionCapture => PieceType.Rook,
                MoveCode.QueenPromotionCapture => PieceType.Queen,
                else => unreachable,
            };
            board.clearPiece(piece.getColor(), pieceType, move.from);
            board.setPiece(piece.getColor(), PieceType.Pawn, move.from);
        }

        if (move.getCode() == MoveCode.KingCastle) {
            const direction: i32 = 1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 3);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, rookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
        } else if (move.getCode() == MoveCode.QueenCastle) {
            const direction: i32 = -1;
            const originalRookSquare: u6 = @intCast(move.from + direction * 4);
            const rookSquare: u6 = @intCast(move.to - direction);
            board.clearPiece(piece.getColor(), PieceType.Rook, rookSquare);
            board.setPiece(piece.getColor(), PieceType.Rook, originalRookSquare);
        }
        board.pieceToMove = move.pieceToMove;
        board.castlingRights = move.castlingRights;
        board.enPassantTarget = move.enPassantTarget;
        board.halfMoveClock = move.halfMoveClock;
        board.fullMoveNumber = move.fullMoveNumber;
    }

    fn updateSelectedSquare(self: *Controller, render: *Render, board: *Board) void {
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            if (self.isMouseOverBoard()) {
                const pos = self.getMousePosition();
                const square = render.getSquareFromPos(pos);

                if (self.selectedSquare.isSelected) {
                    if (self.selectedSquare.square == square) {
                        self.selectedSquare.clear();
                        self.pseudoLegalMoves.clear();
                    }

                    const moves = self.pseudoLegalMoves.constSlice();
                    for (0..moves.len) |i| {
                        const move: Move = moves[i];
                        if (move.to == square) {
                            self.makeMove(board, move);
                            self.selectedSquare.clear();
                            self.pseudoLegalMoves.clear();

                            return;
                        }
                    }
                    self.selectedSquare.setSquare(square);
                    self.updatePseudoLegalMoves(board, render);
                } else {
                    self.selectedSquare.setSquare(square);
                    self.updatePseudoLegalMoves(board, render);
                }
            }
        }
    }

    pub fn update(self: *Controller, deltaTime: f32, render: *Render, board: *Board) void {
        _ = deltaTime;

        if (rl.isKeyPressed(rl.KeyboardKey.u)) {
            if (board.lastMoves.pop()) |lastMove| {
                self.undoMove(board, lastMove);
            }
        }

        self.updateSelectedSquare(render, board);

        // Print the binary representation of castlingRights
        // std.log.info("Castling rights: {b:4}", .{board.castlingRights});
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

    pub fn countPossibleMoves(self: *Controller, board: *Board, render: *Render, depth: u8) u64 {
        if (depth == 0) {
            return 1; // Base case: one possibility at depth 0
        }

        var count: u64 = 0;

        for (0..64) |s| {
            const square = @as(u6, @intCast(s));

            // Dont need to verify if the square is valid,
            //  because updatePseudoLegalMoves already does that
            self.selectedSquare.setSquare(square);
            self.updatePseudoLegalMoves(board, render);

            const moves = self.pseudoLegalMoves.constSlice();
            for (0..moves.len) |i| {
                const move: Move = moves[i];

                // Make the move
                self.makeMove(board, move);

                // std.debug.print("Move: {d} -> {d}\n", .{ move.from, move.to });
                // Render.print(board);

                // Recursively count moves at the next depth
                count += self.countPossibleMoves(board, render, depth - 1);

                if (board.lastMoves.pop()) |lastMove| {
                    self.undoMove(board, lastMove);
                }
            }
        }

        return count;
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
        // board.* = Board.initFromFEN("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1");

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
        self.board.deinit();
        std.heap.c_allocator.destroy(self.render);
        std.heap.c_allocator.destroy(self.board);
        std.heap.c_allocator.destroy(self.controller);
    }
};

var state: GameState = undefined;

fn setup() void {
    state = GameState.init();

    std.log.info("Counting possible moves...", .{});

    for (1..7) |i| {
        var timer = std.time.Timer.start() catch std.debug.panic("Failed to start timer", .{});
        // std.log.info("CountPossibleMoves({d}) = {d}", .{ i, state.controller.countPossibleMoves(state.board, state.render, @intCast(i)) });
        const possibleMoves = state.controller.countPossibleMoves(state.board, state.render, @intCast(i));
        const elapsedTime = timer.read();
        // std.log.info("Elapsed time: {} ms", .{elapsedTime / std.time.ns_per_ms});
        std.log.info("CountPossibleMoves({d}) = {d} ({} ms)", .{ i, possibleMoves, elapsedTime / std.time.ns_per_ms });
    }

    // Render.print(state.board);
}

fn destroy() void {
    state.deinit();
}

fn update(deltaTime: f32) void {
    if (rl.isKeyPressed(rl.KeyboardKey.r)) {
        state.render.inverted = !state.render.inverted;
    }

    state.controller.update(deltaTime, state.render, state.board);
}

fn draw() void {
    rl.clearBackground(rl.Color.init(48, 46, 43, 255));
    state.render.drawBoard();
    // state.render.drawSquareNumbers();
    if (state.controller.selectedSquare.isSelected) {
        state.render.highlightTile(state.controller.selectedSquare.square);
    }
    state.render.drawPieces(state.board);
    state.render.drawPossibleMoves(state.controller);
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
