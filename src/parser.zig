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
    args: std.ArrayList([]const u8),
    stack: utils.Stack(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .args = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
            .stack = utils.Stack(u8).init(allocator),
        };
    }

    pub fn parse(self: *Self, input: []const u8) !void {
        self.clear();

        const last_char_index = if (input.len == 0) 0 else input.len - 1;
        var buffer = std.ArrayList(u8).init(self.allocator);
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
                    const arg = try self.allocator.dupe(u8, buffer.items);
                    while (buffer.items.len > 0) _ = buffer.pop();
                    errdefer self.allocator.free(arg);
                    try self.args.append(arg);
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
                return;
            } else if (self.stack.size() == 1 and self.stack.top == ' ') {
                const arg = try self.allocator.dupe(u8, buffer.items);
                while (buffer.items.len > 0) _ = buffer.pop();
                errdefer self.allocator.free(arg);
                try self.args.append(arg);
            } else {
                return error.ParseError;
            }
        }
    }

    pub fn argv(self: *Self) *[]const []const u8 {
        return &(self.args.items);
    }

    pub fn argc(self: *Self) usize {
        return self.args.items.len;
    }

    pub fn clear(self: *Self) void {
        for (self.args.items) |arg| {
            self.allocator.free(arg);
        }
        self.args.clearRetainingCapacity();
        self.stack.clear();
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        self.args.deinit();
        self.stack.deinit();
    }
};

test "Parser - basic parsing" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    // Test simple space-separated arguments
    try args.parse("hello world");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("hello", args.argv().*[0]);
    try testing.expectEqualStrings("world", args.argv().*[1]);
}

test "Parser - quoted strings" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    // Test single quotes
    try args.parse("'hello world' arg2");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("hello world", args.argv().*[0]);
    try testing.expectEqualStrings("arg2", args.argv().*[1]);

    // Test double quotes
    args.clear();
    try args.parse("\"hello world\" arg2");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("hello world", args.argv().*[0]);
    try testing.expectEqualStrings("arg2", args.argv().*[1]);
}

test "Parser - mixed quotes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("arg1 'hello \"nested\" world' arg3");
    try testing.expectEqual(@as(usize, 3), args.argc());
    try testing.expectEqualStrings("arg1", args.argv().*[0]);
    try testing.expectEqualStrings("hello \"nested\" world", args.argv().*[1]);
    try testing.expectEqualStrings("arg3", args.argv().*[2]);
}

test "Parser - empty input" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("");
    try testing.expectEqual(@as(usize, 0), args.argc());
}

test "Parser - multiple spaces" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("arg1    arg2     arg3");
    try testing.expectEqual(@as(usize, 3), args.argc());
    try testing.expectEqualStrings("arg1", args.argv().*[0]);
    try testing.expectEqualStrings("arg2", args.argv().*[1]);
    try testing.expectEqualStrings("arg3", args.argv().*[2]);
}

test "Parser - clear functionality" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("arg1 arg2");
    try testing.expectEqual(@as(usize, 2), args.argc());

    args.clear();
    try testing.expectEqual(@as(usize, 0), args.argc());
}

test "Parser - parse error for unclosed quotes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try testing.expectError(error.ParseError, args.parse("'unclosed quote"));
    try testing.expectError(error.ParseError, args.parse("\"unclosed quote"));
}

test "Parser - complex parsing" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("command 'arg with spaces' \"another arg\" simple_arg 'quoted \"nested\" arg'");
    try testing.expectEqual(@as(usize, 5), args.argc());
    try testing.expectEqualStrings("command", args.argv().*[0]);
    try testing.expectEqualStrings("arg with spaces", args.argv().*[1]);
    try testing.expectEqualStrings("another arg", args.argv().*[2]);
    try testing.expectEqualStrings("simple_arg", args.argv().*[3]);
    try testing.expectEqualStrings("quoted \"nested\" arg", args.argv().*[4]);
}

test "Parser - consecutive quotes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    // Test double quotes version
    try args.parse("\"script  hello\"  \"world\"\"example\"");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("script  hello", args.argv().*[0]);
    try testing.expectEqualStrings("worldexample", args.argv().*[1]);

    // Test single quotes version
    args.clear();
    try args.parse("'script  hello'  'world''example'");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("script  hello", args.argv().*[0]);
    try testing.expectEqualStrings("worldexample", args.argv().*[1]);

    // Test mixed quotes version
    args.clear();
    try args.parse("\"script  hello\"  'world'\"example\"");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("script  hello", args.argv().*[0]);
    try testing.expectEqualStrings("worldexample", args.argv().*[1]);
}

test "Parser - memory management" {
    var args = Parser.init(testing.allocator);

    // Test multiple parse calls don't leak memory
    try args.parse("test1 test2");
    try args.parse("test3 test4");
    try testing.expectEqual(@as(usize, 2), args.argc());

    args.deinit();
}

test "Parser - escaped single quotes and backslashes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("\"world'hello'\\'shell\"");
    try testing.expectEqual(@as(usize, 1), args.argc());
    try testing.expectEqualStrings("world'hello'\\'shell", args.argv().*[0]);
}

test "Parser - escaped double quotes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("\"world\\\"insidequotes\"hello\\\"");
    try testing.expectEqual(@as(usize, 1), args.argc());
    try testing.expectEqualStrings("world\"insidequoteshello\"", args.argv().*[0]);
}

test "Parser - mixed quotes with escapes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("\"mixed\\\"quote'test'\\\\\"");
    try testing.expectEqual(@as(usize, 1), args.argc());
    try testing.expectEqualStrings("mixed\"quote'test'\\", args.argv().*[0]);
}

test "Parser - complex path with spaces and escapes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("\"/tmp/baz/'f 34'\" \"/tmp/baz/'f  \\81'\" \"/tmp/baz/'f \\4\\'\"");
    try testing.expectEqual(@as(usize, 3), args.argc());
    try testing.expectEqualStrings("/tmp/baz/'f 34'", args.argv().*[0]);
    try testing.expectEqualStrings("/tmp/baz/'f  \\81'", args.argv().*[1]);
    try testing.expectEqualStrings("/tmp/baz/'f \\4\\'", args.argv().*[2]);
}

test "Parser - multiple spaces with escapes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("example\\ \\ \\ \\ \\ \\ hello");
    try testing.expectEqual(@as(usize, 1), args.argc());
    try testing.expectEqualStrings("example      hello", args.argv().*[0]);
}

test "Parser - escaped n character" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("script\\ntest");
    try testing.expectEqual(@as(usize, 1), args.argc());
    try testing.expectEqualStrings("scriptntest", args.argv().*[0]);
}

test "Parser - escaped quotes within single quotes" {
    var args = Parser.init(testing.allocator);
    defer args.deinit();

    try args.parse("\\'\\\"hello script\\\"\\\'");
    try testing.expectEqual(@as(usize, 2), args.argc());
    try testing.expectEqualStrings("'\"hello", args.argv().*[0]);
    try testing.expectEqualStrings("script\"'", args.argv().*[1]);
}
