const i = @import("interface.zig");

const Interface = i.Interface;

pub fn main() !void {
    var interface = Interface.init(&.{});
    interface.run();
}
