const std = @import("std");

const writer = @import("writer.zig");

const BackSlashState = enum {
    Idle,
    Pending,
    Ready,
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    stack: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .stack = std.ArrayList(u8).init(allocator),
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn parse(self: *Self, input: []const u8) ![]const []const u8 {
        defer self.stack.clearAndFree();
        defer self.buffer.clearAndFree();

        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        var last_char: u8 = 0;
        var back_slash_state: BackSlashState = .Idle;
        const last_char_index = if (input.len == 0) 0 else input.len - 1;
        for (input, 0..) |char, i| {
            var char_to_push: u8 = 0;

            const stack_size = self.stack.items.len;
            const stack_top = self.stack.getLastOrNull() orelse 0;

            const char_is_double_quote = char == '"';
            const char_is_single_quote = char == '\'';
            const char_is_quote = char_is_single_quote or char_is_double_quote;
            const char_is_space = char == ' ';

            switch (back_slash_state) {
                .Ready, .Pending => {},
                .Idle => {
                    if (char == '\\' and (stack_top == '"' or stack_top == ' ' or stack_size == 0)) {
                        back_slash_state = .Pending;
                    }

                    if (!char_is_space and stack_size == 0) {
                        if (char_is_quote) {
                            char_to_push = char;
                        } else {
                            char_to_push = ' ';
                        }
                    } else if (stack_size > 0 and char_is_quote and (stack_top == char or stack_top == ' ')) {
                        char_to_push = char;
                    } else if (stack_top == ' ' and stack_size == 1 and char_is_space) {
                        char_to_push = ' ';
                    }
                },
            }

            if (char_to_push != 0) {
                if (stack_top == char_to_push) {
                    _ = self.stack.popOrNull();
                } else {
                    if (stack_size == 0 and (char_is_quote)) {
                        try self.stack.append(' ');
                    }

                    try self.stack.append(char_to_push);
                }

                if (self.stack.items.len == 0) {
                    try args.append(try self.buffer.toOwnedSlice());
                }
            }

            if (self.stack.items.len > 0 and char_to_push != char) {
                switch (back_slash_state) {
                    .Pending => {
                        back_slash_state = .Ready;
                    },
                    .Ready => {
                        if (stack_top == ' ') {
                            _ = self.buffer.popOrNull();
                        } else if (stack_top == '"' and (char == '\\' or char_is_double_quote or char_is_space)) {
                            _ = self.buffer.popOrNull();
                        }

                        back_slash_state = .Idle;
                    },
                    else => {},
                }

                try self.buffer.append(char);
            }

            if (i != last_char_index) {
                last_char = char;
                continue;
            }

            if (self.stack.items.len == 0) {
                return args.toOwnedSlice();
            } else if (self.stack.items.len == 1 and self.stack.getLastOrNull() orelse 0 == ' ') {
                try args.append(try self.buffer.toOwnedSlice());
            } else {
                return error.ParseError;
            }
        }
        return args.toOwnedSlice();
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit();
        self.buffer.deinit();
    }
};

pub fn redirectHandler(
    raw_argv: []const []const u8,
    stdout: *writer.Writer,
    stderr: *writer.Writer,
) ![]const []const u8 {
    if (!(raw_argv.len >= 3)) return error.ParseError;

    if (std.mem.eql(u8, raw_argv[raw_argv.len - 2], ">") or std.mem.eql(u8, raw_argv[raw_argv.len - 2], "1>")) {
        if (stdout.to_file(raw_argv[raw_argv.len - 1], false)) {
            return raw_argv[0 .. raw_argv.len - 2];
        } else {
            try stderr.writer.print("zshell: redirect failed\n", .{});
            return error.RedirectError;
        }
    } else if (std.mem.eql(u8, raw_argv[raw_argv.len - 2], "2>")) {
        if (stderr.to_file(raw_argv[raw_argv.len - 1], false)) {
            return raw_argv[0 .. raw_argv.len - 2];
        } else {
            try stderr.writer.print("zshell: redirect failed\n", .{});
            return error.RedirectError;
        }
    } else if (std.mem.eql(u8, raw_argv[raw_argv.len - 2], ">>") or std.mem.eql(u8, raw_argv[raw_argv.len - 2], "1>>")) {
        if (stdout.to_file(raw_argv[raw_argv.len - 1], true)) {
            return raw_argv[0 .. raw_argv.len - 2];
        } else {
            try stderr.writer.print("zshell: redirect failed\n", .{});
            return error.RedirectError;
        }
    } else if (std.mem.eql(u8, raw_argv[raw_argv.len - 2], "2>>")) {
        if (stderr.to_file(raw_argv[raw_argv.len - 1], true)) {
            return raw_argv[0 .. raw_argv.len - 2];
        } else {
            try stderr.writer.print("zshell: redirect failed\n", .{});
            return error.RedirectError;
        }
    }

    return error.ParseError;
}
