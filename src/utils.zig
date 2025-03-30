const std = @import("std");
const rl = @import("raylib");

pub const IVector2 = struct {
    x: i32,
    y: i32,

    pub fn eql(self: IVector2, other: IVector2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn init(x: i32, y: i32) IVector2 {
        return IVector2{ .x = x, .y = y };
    }

    pub fn fromVector2(vector: rl.Vector2) IVector2 {
        return IVector2.init(
            @as(i32, @intFromFloat(vector.x)),
            @as(i32, @intFromFloat(vector.y)),
        );
    }

    pub fn toVector2(self: IVector2) rl.Vector2 {
        return rl.Vector2.init(
            @as(f32, @floatFromInt(self.x)),
            @as(f32, @floatFromInt(self.y)),
        );
    }
};

pub fn iVector2Eq(a: IVector2, b: IVector2) bool {
    return a.eql(b);
}
