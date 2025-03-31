// Responsabilities of the BoardManager module:
// - Drawing the pieces;
// - Handling the interation of the player with the pieces;
// - Making the piece movement animation;
// TODO: Maybe something for a later moment

const std = @import("std");
const rl = @import("raylib");
const board = @import("board.zig");
const Board = board.Board;

pub const BoardManager = struct {
    board: *Board,

    pub fn init() BoardManager {
        return BoardManager{
            .board = Board.init(),
        };
    }

    pub fn deinit(self: *BoardManager) void {
        self.board.deinit();
    }
};
