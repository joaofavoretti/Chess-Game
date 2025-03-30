const std = @import("std");
const rl = @import("raylib");

pub const IVector2 = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) IVector2 {
        return IVector2{ .x = x, .y = y };
    }

    pub fn fromVector2(vector: rl.Vector2) IVector2 {
        return IVector2.init(
            @as(i32, @intCast(vector.x)),
            @as(i32, @intCast(vector.y)),
        );
    }

    pub fn toVector2(self: IVector2) rl.Vector2 {
        return rl.Vector2.init(
            @as(f32, @floatFromInt(self.x)),
            @as(f32, @floatFromInt(self.y)),
        );
    }
};
