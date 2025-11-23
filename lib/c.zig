pub const c = @cImport({
    @cDefine("_XOPEN_SOURCE", "600");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("fcntl.h");
    @cInclude("pty.h");
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("stdint.h");
    @cInclude("errno.h");
    @cInclude("libgen.h");
    @cInclude("sys/select.h");
});
