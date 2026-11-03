const std = @import("std");

/// Fixed storage keeps per-tick work bounded without allocations.
fn FixedQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        count: usize = 0,
        const Self = @This();

        pub fn push(self: *Self, item: T) error{Full}!void {
            if (self.count == self.items.len) return error.Full;
            self.items[self.count] = item;
            self.count += 1;
        }

        pub fn slice(self: *const Self) []const T {
            return self.items[0..self.count];
        }
    };
}

pub fn main() !void {
    var queue: FixedQueue(u16, 4) = .{};
    try queue.push(40);
    try queue.push(2);
    std.debug.print("{s}: {any}\n", .{ "queued", queue.slice() });
}
