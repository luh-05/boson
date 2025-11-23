const c = @import("c.zig").c;
const pty_master_open = @import("pty_master_open.zig").pty_master_open;

pub fn ptyFork(master_fd: *i32, slave_name: *u8, sn_len: usize, termios: *const c.termios, slave_ws: **const c.winsize) usize {
    _ = master_fd; // autofix
    _ = slave_name; // autofix
    _ = sn_len; // autofix
    _ = termios; // autofix
    _ = slave_ws; // autofix

    // Open pty
}
