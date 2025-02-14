const std = @import("std");

const termios = @import("termios.zig");
const Writer = @import("writer.zig");

allocator: std.mem.Allocator,
buffer: std.ArrayList(u8),
cursor_pos: usize,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .buffer = std.ArrayList(u8).init(allocator),
        .cursor_pos = 0,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.buffer.deinit();
}

pub fn clear(self: *Self) void {
    self.buffer.clearRetainingCapacity();
    self.cursor_pos = 0;
}

pub fn readChar(self: *Self, stdout: *Writer) !bool {
    const stdin = std.io.getStdIn().reader();
    var buf: [1]u8 = undefined;
    const bytes_read = try stdin.read(&buf);

    if (bytes_read == 0) {
        return true; // EOF
    }

    const char = buf[0];

    switch (char) {
        27 => {
            // Arrow keys and other special sequences
            var seq: [2]u8 = undefined;
            const bytes_read_seq = try stdin.read(&seq);
            if (bytes_read_seq != 2) {
                return false; // Incomplete sequence
            }

            if (seq[0] == '[') {
                switch (seq[1]) {
                    'D' => {
                        // Left arrow
                        if (self.cursor_pos > 0) {
                            self.cursor_pos -= 1;
                            try stdout.print("\x1b[D", .{});
                        }
                    },
                    'C' => {
                        // Right arrow
                        if (self.cursor_pos < self.buffer.items.len) {
                            self.cursor_pos += 1;
                            try stdout.print("\x1b[C", .{});
                        }
                    },
                    else => {},
                }
            }
        },
        127 => {
            // Backspace
            if (!(self.cursor_pos > 0)) return false;
            if (self.cursor_pos == self.buffer.items.len) {
                // Remove character from buffer
                _ = self.buffer.popOrNull();
                self.cursor_pos -= 1;

                // ANSI backspace
                try stdout.print("\x1b[D\x1b[K", .{});
            } else {
                // Remove character from buffer
                _ = self.buffer.orderedRemove(self.cursor_pos - 1);
                const tail = self.buffer.items[self.cursor_pos - 1 ..];
                self.cursor_pos -= 1;

                try stdout.print("\x1b[D\x1b[K", .{});

                try stdout.print("{s}", .{tail});
                for (0..tail.len) |_| {
                    try stdout.print("\x1b[D", .{});
                }
            }
        },
        '\n' => {
            // Enter
            try stdout.print("\n", .{});
            return true;
        },
        else => {
            // Normal character
            try self.buffer.insert(self.cursor_pos, char);
            self.cursor_pos += 1;

            // Print the char
            if (self.cursor_pos == self.buffer.items.len) {
                try stdout.print("{c}", .{char});
            } else {
                const tail = self.buffer.items[self.cursor_pos - 1 ..];
                try stdout.print("\x1b[K{s}", .{tail});
                for (0..tail.len - 1) |_| {
                    try stdout.print("\x1b[D", .{});
                }
            }
        },
    }

    return false;
}

pub fn readLine(self: *Self, stdout: *Writer) ![]const u8 {
    self.clear();
    try termios.setTerminalEcho(false);
    defer termios.setTerminalEcho(true) catch {};

    while (true) {
        const read_complete = try self.readChar(stdout);
        if (read_complete) {
            break;
        }
    }

    return self.buffer.toOwnedSlice();
}
