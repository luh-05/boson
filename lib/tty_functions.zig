const std = @import("std");
const c = @import("c.zig").c;

pub fn ttySetRaw(fd: i32, termios: ?*c.termios) !void {
    var t: c.termios = c.termios{};

    if (c.tcgetattr(fd, &t) == -1) {
        return error.PTY_ERR_GET_ATTR;
    }

    if (termios != null) {
        termios.?.* = t;
    }

    // Set noncanonical mode, disable signals, exten input procesdsing, enable echoing
    t.c_lflag &= @intCast(~@as(c.tcflag_t, (c.ICANON | c.ISIG | c.IEXTEN | c.ECHO)));
    // t.c_lflag &= @bitCast(~(c.ICANON | c.ISIG | c.IEXTEN | c.ECHO));

    // Disable special handling of CR, NL and BREAK. Diable 8th-bit stripping or parity error handling. Also disable START/STOP output flow control.
    t.c_iflag &= @intCast(~@as(c.tcflag_t, (c.BRKINT | c.ICRNL | c.IGNBRK | c.IGNCR | c.INLCR | c.INPCK | c.ISTRIP | c.IXON | c.PARMRK)));
    // t.c_iflag &= @bitCast(~(c.BRKINT | c.ICRNL | c.IGNBRK | c.IGNCR | c.INLCR | c.INPCK | c.ISTRIP | c.IXON | c.PARMRK));

    // Disable output processing
    t.c_oflag &= @intCast(~@as(c.tcflag_t, (c.OPOST)));
    // t.c_oflag &= @bitCast(~(c.OPOST));

    // Enable one-character-at-a-time input
    t.c_cc[c.VMIN] = 1;
    // with blocking
    t.c_cc[c.VTIME] = 0;

    // Set new attributes
    if (c.tcsetattr(fd, c.TCSANOW, &t) == -1) {
        return error.PTY_ERR_SET_ATTR;
    }
}
