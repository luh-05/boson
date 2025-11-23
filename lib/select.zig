const c = @import("c.zig").c;

// Reimplementation of https://codebrowser.dev/qt6/include/x86_64-linux-gnu/bits/select.h.html
// Zig doesn't parse the definitions correctly natively

const NFDBITS = @sizeOf(usize) * 8;

pub fn fdZero(s: *c.fd_set) void {
    for (&s.fds_bits) |*word| {
        word.* = 0;
    }
}

pub fn fdSet(fd: usize, s: *c.fd_set) void {
    const idx = fd / NFDBITS;
    const bit: u5 = @intCast(fd % NFDBITS);
    s.fds_bits[idx] |= (@as(i32, 1) << bit);
}

pub fn fdClr(fd: usize, s: *c.fd_set) void {
    const idx = fd / NFDBITS;
    const bit: u5 = @intCast(fd % NFDBITS);
    s.fds_bits[idx] &= ~(@as(i32, 1) << bit);
}

pub fn fdIsSet(fd: usize, s: *c.fd_set) bool {
    const idx = fd / NFDBITS;
    const bit: u5 = @intCast(fd % NFDBITS);
    return (s.fds_bits[idx] & (@as(i32, 1) << bit)) != 0;
}
