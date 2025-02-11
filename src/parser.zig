const std = @import("std");
const utils = @import("utils.zig");

const testing = std.testing;

const BackSlashState = enum {
    idle,
    pending,
    ready,
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

        const last_char_index = if (input.len == 0) 0 else input.len - 1;
        var buffer = std.ArrayList(u8).init(self.allocator);
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();
        defer buffer.deinit();

        var last_char: u8 = 0;
        var back_slash_state: BackSlashState = .idle;
        for (input, 0..) |char, i| {
            var char_to_push: u8 = 0;

            const stack_size = self.stack.size();
            const stack_top = self.stack.top orelse 0;

            const char_is_double_quote = char == '"';
            const char_is_single_quote = char == '\'';
            const char_is_quote = char_is_single_quote or char_is_double_quote;
            const char_is_space = char == ' ';

            switch (back_slash_state) {
                .ready, .pending => {},
                .idle => {
                    if (char == '\\' and (stack_top == '"' or stack_top == ' ' or stack_size == 0)) {
                        back_slash_state = .pending;
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
                    .pending => {
                        back_slash_state = .ready;
                    },
                    .ready => {
                        if (stack_top == ' ') {
                            _ = buffer.popOrNull();
                        } else if (stack_top == '"' and (char == '\\' or char_is_double_quote or char_is_space)) {
                            _ = buffer.popOrNull();
                        }

                        back_slash_state = .idle;
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
