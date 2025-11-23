const std = @import("std");
const root = @import("bosonlib");
const c = root.c;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var mfd: i32 = 0;
    var slave_name: []const u8 = "";
    const termios: c.termios = c.termios{};
    const ws: c.winsize = c.winsize{};
    const pid = root.ptyFork(alloc, &mfd, &slave_name, &termios, &ws) catch |err| {
        return err;
    };
    defer alloc.free(slave_name);
    std.debug.print("pid: {d}, slave_name: {s}, mfd: {d}\n", .{ pid, slave_name, mfd });
}
