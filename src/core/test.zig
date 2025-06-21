const std = @import("std");
const core = @import("core.zig");
const testing = std.testing;

test "Basic Perft Tests" {
    var board = core.Board.initFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    defer board.deinit();
    const perft_res = [_]usize{ 20, 400, 8902, 197281, 4865609 };
    for (perft_res, 1..) |expected, depth| {
        const result = core.perft(&board, depth);
        try testing.expectEqual(expected, result);
    }
}

test "Position 2" {
    var board = core.Board.initFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1");
    defer board.deinit();
    const perft_res = [_]usize{ 48, 2039, 97862 };
    for (perft_res, 1..) |expected, depth| {
        const result = core.perft(&board, depth);
        try testing.expectEqual(expected, result);
    }
}

test "Position 3" {
    var board = core.Board.initFEN("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
    defer board.deinit();
    const perft_res = [_]usize{ 14, 191, 2812 };
    for (perft_res, 1..) |expected, depth| {
        const result = core.perft(&board, depth);
        try testing.expectEqual(expected, result);
    }
}

test "Position 4" {
    var board = core.Board.initFEN("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    defer board.deinit();
    const perft_res = [_]usize{ 6, 264, 9467 };
    for (perft_res, 1..) |expected, depth| {
        const result = core.perft(&board, depth);
        try testing.expectEqual(expected, result);
    }
}

test "Position 5" {
    // rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8
    var board = core.Board.initFEN("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    defer board.deinit();
    const perft_res = [_]usize{ 44, 1486, 62379 };
    for (perft_res, 1..) |expected, depth| {
        const result = core.perft(&board, depth);
        try testing.expectEqual(expected, result);
    }
}

test "Position 6" {
    // r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10
    var board = core.Board.initFEN("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10");
    defer board.deinit();
    const perft_res = [_]usize{ 46, 2079, 89890 };
    for (perft_res, 1..) |expected, depth| {
        const result = core.perft(&board, depth);
        try testing.expectEqual(expected, result);
    }
}

// TODO: Use the Chess960 Perft Result CSV
// CSV lib: https://github.com/beho/zig-csv
test "Batch Test" {}
