const std = @import("std");
const utils = @import("utils.zig");

const testing = std.testing;

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

        for (input, 0..) |char, i| {
            var char_to_push: ?u8 = null;
            const stack_size = self.stack.size();
            const stack_top = self.stack.top orelse 0;
            const char_is_double_quote = char == '"';
            const char_is_single_quote = char == '\'';
            const char_is_quote = char_is_single_quote or char_is_double_quote;
            const char_is_space = char == ' ';

            if (!char_is_space and stack_size == 0) {
                if (char_is_quote) {
                    char_to_push = char;
                } else {
                    char_to_push = ' ';
                }
            } else if (stack_size > 0 and char_is_quote and (stack_top == char or stack_top == ' ')) {
                char_to_push = char;
            } else if (stack_top == ' ' and stack_size == 1 and char_is_space) {
                char_to_push = char;
            }

            var append_sentry: u8 = 0;
            if (char_to_push) |c| {
                append_sentry = c;
                if (stack_top == c) {
                    _ = self.stack.pop();
                } else {
                    if (stack_size == 0 and (char_is_quote)) {
                        try self.stack.push(' ');
                    }
                    try self.stack.push(c);
                }

                if (self.stack.size() == 0) {
                    const arg = try self.allocator.dupe(u8, buffer.items);
                    while (buffer.items.len > 0) _ = buffer.pop();
                    errdefer self.allocator.free(arg);
                    try self.args.append(arg);
                }
            }

            // std.debug.print("char {c}, state {any}\n", .{ char, state });
            if (self.stack.size() > 0 and char != append_sentry) {
                try buffer.append(char);
            }

            if (i != last_char_index) continue;

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
