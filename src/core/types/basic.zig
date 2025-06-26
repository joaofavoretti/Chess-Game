pub const Bitboard = u64;

pub const SelectedSquare = struct {
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
