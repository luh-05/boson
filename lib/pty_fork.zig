const std = @import("std");
const c = @import("c.zig").c;
const ptyMasterOpen = @import("pty_master_open.zig").ptyMasterOpen;
const closeFD = @import("pty_master_open.zig").closeFD;

pub fn ptyFork(alloc: std.mem.Allocator, master_fd: *i32, slave_name: ?*[]const u8, termios: ?*const c.termios, slave_ws: ?*const c.winsize) !i32 {

    // Open pty
    var sl_name: []const u8 = "";
    const mfd = ptyMasterOpen(alloc, &sl_name) catch |err| {
        return err;
    };
    defer alloc.free(sl_name);

    // Return slave name to caller
    if (slave_name) |val| {
        val.* = alloc.dupe(u8, sl_name) catch {
            return error.PTY_ERR_DUPE_SLAVE_NAME;
        };
    }

    // Fork
    const child_pid = c.fork();
    if (child_pid == -1) {
        closeFD(mfd);
        return error.PTY_ERR_FORK;
    }

    // Check if parent
    if (child_pid != 0) {
        // Process must be parent
        master_fd.* = mfd;
        return child_pid;
    }

    // -- Only child falls through --

    // Start new session
    if (c.setsid() == -1) {
        return error.PTY_ERR_CREATING_SESSION;
    }

    // Master file descriptor not needed in child
    closeFD(mfd);

    // Set slave to become ctty
    const t: [*c]const u8 = @ptrCast(sl_name);
    const sfd = c.open(t, c.O_RDWR);
    if (sfd == -1) {
        return error.PTY_ERR_OPEN_SLAVE;
    }

    // Set slave TTY attributes
    if (termios) |opt| {
        if (c.tcsetattr(sfd, c.TCSANOW, opt) == -1) {
            return error.PTY_ERR_SET_SLAVE_ATTR;
        }
    }

    // Set slave window size
    if (slave_ws) |opt| {
        if (c.ioctl(sfd, c.TIOCSWINSZ, opt) == -1) {
            return error.PTY_ERR_SET_SLAVE_WIN_SIZE;
        }
    }

    // Duplicate pty slave to be child's stdin, stdout and stderr
    if (c.dup2(sfd, c.STDIN_FILENO) != c.STDIN_FILENO) {
        return error.PTY_ERR_DUPE_STDIN;
    }
    if (c.dup2(sfd, c.STDOUT_FILENO) != c.STDOUT_FILENO) {
        return error.PTY_ERR_DUPE_STDOUT;
    }
    if (c.dup2(sfd, c.STDERR_FILENO) != c.STDERR_FILENO) {
        return error.PTY_ERR_DUPE_STDERR;
    }

    // Safety check
    if (sfd > c.STDERR_FILENO) {
        closeFD(sfd);
    }

    return 0;
}
