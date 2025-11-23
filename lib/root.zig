pub const c = @import("c.zig").c;

pub const ptyMasterOpen = @import("pty_master_open.zig").ptyMasterOpen;
pub const ptyFork = @import("pty_fork.zig").ptyFork;
pub const ttyFunctions = @import("tty_functions.zig");
pub const select = @import("select.zig");
