const std = @import("std");

const termios = @import("termios.zig");
const Writer = @import("writer.zig");
const Trie = @import("trie.zig");

allocator: std.mem.Allocator,
buffer: std.ArrayList(u8),
cursor_pos: usize,
trie: *Trie,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, trie: *Trie) Self {
    return Self{
        .buffer = std.ArrayList(u8).init(allocator),
        .cursor_pos = 0,
        .allocator = allocator,
        .trie = trie,
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
        '\t' => {
            // tab completion
            if (self.cursor_pos != self.buffer.items.len) {
                std.debug.print("mismatch\n", .{});
                // only complete when cursor is at the end
                return false;
            }

            var to_complete: ?[]const u8 = null;

            const buffer_last_index = self.buffer.items.len - 1;
            for (self.buffer.items, 0..) |item, i| {
                if (item == ' ' and i != 0) {
                    to_complete = self.buffer.items[0..i];
                    break;
                } else if (i == buffer_last_index) {
                    to_complete = self.buffer.items[0 .. i + 1];
                    break;
                }
            }

            if (to_complete == null) return false;

            const completions = try self.trie.findWithPrefix(to_complete.?);
            defer {
                for (completions) |c| self.allocator.free(c);
                self.allocator.free(completions);
            }
            if (completions.len == 0) {
                try stdout.print("{c}", .{7}); // bell
                return false;
            } else if (completions[0].len == to_complete.?.len) {
                return false;
            }

            // completion
            if (self.cursor_pos == to_complete.?.len) {
                const slice = completions[0][to_complete.?.len..];
                try stdout.print("{s} ", .{slice});
                try self.buffer.appendSlice(slice);
                try self.buffer.append(' ');
                self.cursor_pos += (slice.len + 1);
            } else {
                const slice = completions[0][to_complete.?.len..];
                for (slice, to_complete.?.len..) |c, i| {
                    try self.buffer.insert(i, c);
                }

                for (0..self.cursor_pos - to_complete.?.len) |_| {
                    try stdout.print("\x1b[D", .{});
                }

                const tail = self.buffer.items[to_complete.?.len..];
                try stdout.print("\x1b[K{s}", .{tail});

                self.cursor_pos += slice.len;
            }

            return false;
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
