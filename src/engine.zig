const std = @import("std");
const rl = @import("raylib");
const Board = @import("board.zig").Board;

// TODO: Took the design from
// https://github.com/tigerbeetle/tigerbeetle/blob/e0c33c8a72fc095290ff69fa995bac59627e0e75/src/clients/c/tb_client/context.zig#L33

pub const EngineInterface = struct {
    makeMove: *const fn (self: *anyopaque) void,
};

pub const BaseEngine = struct {
    impl: *anyopaque,
    vtable: EngineInterface,

    pub fn makeMove(self: *BaseEngine) void {
        self.vtable.makeMove(self.impl);
    }
};

pub const RandomEngine = struct {
    board: *Board,

    pub fn init(board: *Board) BaseEngine {
        const engine = std.heap.page_allocator.create(RandomEngine) catch std.debug.panic("Failed to allocate RandomEngine", .{});
        engine.* = .{
            .board = board,
        };
        return BaseEngine{
            .impl = engine,
            .vtable = EngineInterface{
                .makeMove = &RandomEngine.makeMove,
            },
        };
    }

    pub fn deinit(self: *BaseEngine) void {
        const randomEngine: *RandomEngine = @ptrCast(@alignCast(self.impl));
        std.heap.page_allocator.destroy(randomEngine);
    }

    pub fn makeMove(context: *anyopaque) void {
        const self: *RandomEngine = @ptrCast(@alignCast(context));

        if (self.board.isGameOver) {
            std.debug.print("[Engine] Game is over, no moves can be made\n", .{});
            return;
        }

        const moves = self.board.getAllValidMoves() catch std.debug.panic("Failed to get all valid moves", .{});

        var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        var random = rng.random();
        const randomIndex = random.uintLessThan(usize, moves.items.len);
        const move = moves.items[randomIndex];

        self.board.makeMove(move);
        moves.deinit();
    }
};
