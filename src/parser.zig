const std = @import("std");

const utils = @import("utils.zig");
const writer = @import("writer.zig");

const testing = std.testing;

const BackSlashState = enum {
    Idle,
    Pending,
    Ready,
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    stack: utils.Stack(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .stack = utils.Stack(u8).init(allocator),
        };
    }

    pub fn parse(self: *Self, input: []const u8) ![]const []const u8 {
        self.stack.clear();

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        var last_char: u8 = 0;
        var back_slash_state: BackSlashState = .Idle;
        const last_char_index = if (input.len == 0) 0 else input.len - 1;
        for (input, 0..) |char, i| {
            var char_to_push: u8 = 0;

            const stack_size = self.stack.size();
            const stack_top = self.stack.top orelse 0;

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
                    _ = self.stack.pop();
                } else {
                    if (stack_size == 0 and (char_is_quote)) {
                        try self.stack.push(' ');
                    }

                    try self.stack.push(char_to_push);
                }

                if (self.stack.size() == 0) {
                    try args.append(try buffer.toOwnedSlice());
                }
            }

            if (self.stack.size() > 0 and char_to_push != char) {
                switch (back_slash_state) {
                    .Pending => {
                        back_slash_state = .Ready;
                    },
                    .Ready => {
                        if (stack_top == ' ') {
                            _ = buffer.popOrNull();
                        } else if (stack_top == '"' and (char == '\\' or char_is_double_quote or char_is_space)) {
                            _ = buffer.popOrNull();
                        }

                        back_slash_state = .Idle;
                    },
                    else => {},
                }

                try buffer.append(char);
            }

            if (i != last_char_index) {
                last_char = char;
                continue;
            }

            if (self.stack.isEmpty()) {
                return args.toOwnedSlice();
            } else if (self.stack.size() == 1 and self.stack.top == ' ') {
                try args.append(try buffer.toOwnedSlice());
            } else {
                return error.ParseError;
            }
        }
        return args.toOwnedSlice();
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit();
    }
};

pub fn redirectHandler(
    allocator: std.mem.Allocator,
    raw_argv: []const []const u8,
    stdout: *writer.Writer,
    stderr: *writer.Writer,
) ![]const []const u8 {
    if (!(raw_argv.len >= 3)) return error.ParseError;

    var argv: []const []const u8 = undefined;
    if (std.mem.eql(u8, raw_argv[raw_argv.len - 2], ">") or std.mem.eql(u8, raw_argv[raw_argv.len - 2], "1>")) {
        if (stdout.to_file(raw_argv[raw_argv.len - 1])) {
            argv = try allocator.dupe([]const u8, raw_argv[0 .. raw_argv.len - 2]);
            return argv;
        } else {
            try stderr.writer.print("zshell: redirect failed\n", .{});
            return error.RedirectError;
        }
    } else if (std.mem.eql(u8, raw_argv[raw_argv.len - 2], "2>")) {
        if (stderr.to_file(raw_argv[raw_argv.len - 1])) {
            argv = try allocator.dupe([]const u8, raw_argv[0 .. raw_argv.len - 2]);
            return argv;
        } else {
            try stderr.writer.print("zshell: redirect failed\n", .{});
            return error.RedirectError;
        }
    }

    return error.ParseError;
}
