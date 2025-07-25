const std = @import("std");

pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn eql(self: Vector2, other: Vector2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn init(x: f32, y: f32) Vector2 {
        return Vector2{ .x = x, .y = y };
    }

    pub fn fromIVector2(vector: IVector2) Vector2 {
        return Vector2.init(
            @as(f32, @floatFromInt(vector.x)),
            @as(f32, @floatFromInt(vector.y)),
        );
    }

    pub fn toIVector2(self: Vector2) IVector2 {
        return IVector2.init(
            @as(i32, @intFromFloat(self.x)),
            @as(i32, @intFromFloat(self.y)),
        );
    }
};

pub fn Vector2Eq(a: Vector2, b: Vector2) bool {
    return a.eql(b);
}

pub fn Vector2Add(a: Vector2, b: Vector2) Vector2 {
    return Vector2.init(a.x + b.x, a.y + b.y);
}

pub const IVector2 = struct {
    x: i32,
    y: i32,

    pub fn eql(self: IVector2, other: IVector2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn init(x: i32, y: i32) IVector2 {
        return IVector2{ .x = x, .y = y };
    }

    pub fn fromVector2(vector: Vector2) IVector2 {
        return IVector2.init(
            @as(i32, @intFromFloat(vector.x)),
            @as(i32, @intFromFloat(vector.y)),
        );
    }

    pub fn toVector2(self: IVector2) Vector2 {
        return Vector2.init(
            @as(f32, @floatFromInt(self.x)),
            @as(f32, @floatFromInt(self.y)),
        );
    }
};

pub fn IVector2Eq(a: IVector2, b: IVector2) bool {
    return a.eql(b);
}

pub fn IVector2Add(a: IVector2, b: IVector2) IVector2 {
    return IVector2.init(a.x + b.x, a.y + b.y);
}
