const std = @import("std");
const builtin = @import("builtin");

pub fn setTerminalEcho(enable: bool) !void {
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) {
        // On non-POSIX platforms, you need to use platform-specific APIs.
        // For example, on Windows use GetConsoleMode and SetConsoleMode.
        return error.UnsupportedPlatform;
    }

    const tty_fd: i32 = std.posix.STDIN_FILENO; // Standard input file descriptor

    var termios = try std.posix.tcgetattr(tty_fd);

    // Modify the attributes to disable or enable echo.
    termios.lflag.ECHO = enable;
    termios.lflag.ICANON = enable;

    // Apply the modified attributes.
    try std.posix.tcsetattr(tty_fd, std.posix.TCSA.NOW, termios);
}
