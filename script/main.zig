const std = @import("std");
const root = @import("bosonlib");
const c = root.c;

const BUF_SIZE: usize = 256;

var termios: c.termios = c.termios{};

fn isSlave(child_pid: i32) bool {
    return child_pid == 0;
}

fn ttyReset() callconv(.c) void {
    if (c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &termios) == -1) {
        c.exit(c.EXIT_FAILURE);
        // std.debug.print("Failed setting attributes in ttyReset!", .{});
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var mfd: i32 = 0;
    var slave_name: []const u8 = "";
    var ws: c.winsize = c.winsize{};

    if (c.tcgetattr(c.STDIN_FILENO, &termios) == -1) {
        return error.SCT_ERR_GET_ATTR;
    }
    if (c.ioctl(c.STDIN_FILENO, c.TIOCGWINSZ, &ws) == -1) {
        return error.SCT_ERR_GET_WIN_SIZE;
    }

    const child_pid = root.ptyFork(alloc, &mfd, &slave_name, &termios, &ws) catch |err| {
        return err;
    };
    if (!std.mem.eql(u8, slave_name, "")) {
        defer alloc.free(slave_name);
    }
    // std.debug.print("termios: {}\nws: {}\n", .{ termios, ws });
    // std.debug.print("pid: {d}, slave_name: {s}, mfd: {d}\n", .{ pid, slave_name, mfd });

    // Execute a shell on slave
    if (isSlave(child_pid)) {
        // -- Child code --
        var shell: [*c]const u8 = c.getenv("SHELL");
        if ((shell == null) or (shell.* == 0)) {
            shell = "/bin/sh";
        }
        _ = c.execlp(shell, shell, c.NULL);
        return error.SCT_ERR_EXEC_SHELL; // Shouldn't be reachable unless execlp failed
    }

    // -- Parent code --
    // Relay data between Terminal and pty master

    // Open typescript
    const script_fd = c.open(if (std.os.argv.len > 1) std.os.argv[1] else "typescript", @bitCast(c.O_RDWR | c.O_CREAT | c.O_TRUNC));

    if (script_fd == -1) {
        return error.SCR_ERR_OPEN_TYPESCRIPT;
    }

    root.ttyFunctions.ttySetRaw(c.STDIN_FILENO, &termios) catch |err| {
        return err;
    };

    if (c.atexit(ttyReset) != 0) {
        return error.SCR_ERR_ATEXIT;
    }

    var in_fds: c.fd_set = c.fd_set{};
    // var num_read: usize = 0;
    const buf: []u8 = alloc.alloc(u8, BUF_SIZE) catch {
        return error.SCR_ERR_ALLOCATE_BUFFER;
    };
    defer alloc.free(buf);
    while (true) {
        root.select.fdZero(&in_fds);
        root.select.fdSet(c.STDIN_FILENO, &in_fds);
        root.select.fdSet(@intCast(mfd), &in_fds);

        if (c.select(mfd + 1, &in_fds, null, null, null) == -1) {
            return error.SCR_ERR_SELECT;
        }

        // stdin -> pty
        if (root.select.fdIsSet(c.STDIN_FILENO, &in_fds)) {
            const num_read = c.read(c.STDIN_FILENO, @ptrCast(buf), BUF_SIZE);
            if (num_read <= 0) {
                c.exit(c.EXIT_SUCCESS);
            }

            if (c.write(mfd, @ptrCast(buf), @intCast(num_read)) != num_read) {
                return error.SCR_ERR_WRITE_PTY;
            }
        }

        // pty -> stdout+typescript
        if (root.select.fdIsSet(@intCast(mfd), &in_fds)) {
            const num_read = c.read(mfd, @ptrCast(buf), BUF_SIZE);
            if (num_read <= 0) {
                c.exit(c.EXIT_SUCCESS);
            }

            if (c.write(c.STDOUT_FILENO, @ptrCast(buf), @intCast(num_read)) != num_read) {
                return error.SCR_ERR_WRITE_STDOUT;
            }
            if (c.write(script_fd, @ptrCast(buf), @intCast(num_read)) != num_read) {
                return error.SCR_ERR_WRITE_TYPESCRIPT;
            }
        }
    }
}
