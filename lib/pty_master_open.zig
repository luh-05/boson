const std = @import("std");
const c = @import("c.zig").c;

pub fn closeFD(master_fd: i32) void {
    // const saved_errno = c.errno;
    _ = c.close(master_fd);
    // c.errno = saved_errno;
}

pub fn ptyMasterOpen(alloc: std.mem.Allocator, slave_name: *[]const u8) !i32 {

    // Open pty master
    const master_fd = c.posix_openpt(c.O_RDWR | c.O_NOCTTY);
    if (master_fd == -1) {
        return error.PTY_ERR_OPENING_PTY_MASTER;
    }

    // Grant slave permissions
    if (c.grantpt(master_fd) == -1) {
        closeFD(master_fd);
        return error.PTY_ERR_SETTING_SLAVE_PERMISSIONS;
    }

    // Unlock slave pty
    if (c.unlockpt(master_fd) == -1) {
        closeFD(master_fd);
        return error.PTY_ERR_UNLOCK_SLAVE;
    }

    // Get slave pty name
    const p: ?[*c]u8 = c.ptsname(master_fd);
    if (p == null) {
        closeFD(master_fd);
        return error.PTY_ERR_GET_SLAVE_NAME;
    }

    slave_name.* = alloc.dupeZ(u8, std.mem.span(p.?)) catch {
        return error.PTR_ERR_FAILED_COPYING_SLAVE_NAME;
    };

    return master_fd;
}
