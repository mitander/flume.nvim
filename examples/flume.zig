const std = @import("std");

// The caller chooses whether a missing port is an error or null.
// Inspired by matklad's "A Fun Zig Program":
// https://matklad.github.io/2025/04/21/fun-zig-program.html
fn parsePort(comptime required: bool, text: []const u8) !(if (required) u16 else ?u16) {
    if (text.len == 0) {
        if (required) return error.MissingPort;
        return null;
    }
    const port = try std.fmt.parseInt(u16, text, 10);
    if (port == 0) return error.ReservedPort;
    return port;
}

pub fn main() !void {
    const explicit = try parsePort(true, "8080");
    const fallback = try parsePort(false, "") orelse 3000;
    std.debug.print("explicit: {d}, fallback: {d}\n", .{ explicit, fallback });
}

test "required changes the return type, not just the value" {
    try std.testing.expectEqual(@as(u16, 8080), try parsePort(true, "8080"));
    try std.testing.expectEqual(@as(?u16, null), try parsePort(false, ""));
    try std.testing.expectError(error.MissingPort, parsePort(true, ""));
    try std.testing.expectError(error.ReservedPort, parsePort(false, "0"));
}
