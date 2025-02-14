const std = @import("std");
const testing = std.testing;

const Parser = @import("../parser.zig");

test "Parser - basic parsing" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    // Test simple space-separated arguments
    const result = try p.parse("hello world");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 2), result.len);
    try testing.expectEqualStrings("hello", result[0]);
    try testing.expectEqualStrings("world", result[1]);
}

test "Parser - quoted strings" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    // Test single quotes
    const result1 = try p.parse("'hello world' arg2");
    defer {
        for (result1) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result1);
    }
    try testing.expectEqual(@as(usize, 2), result1.len);
    try testing.expectEqualStrings("hello world", result1[0]);
    try testing.expectEqualStrings("arg2", result1[1]);

    // Test double quotes
    const result2 = try p.parse("\"hello world\" arg2");
    defer {
        for (result2) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result2);
    }
    try testing.expectEqual(@as(usize, 2), result2.len);
    try testing.expectEqualStrings("hello world", result2[0]);
    try testing.expectEqualStrings("arg2", result1[1]);
}

test "Parser - mixed quotes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("arg1 'hello \"nested\" world' arg3");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqualStrings("arg1", result[0]);
    try testing.expectEqualStrings("hello \"nested\" world", result[1]);
    try testing.expectEqualStrings("arg3", result[2]);
}

test "Parser - empty input" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 0), result.len);
}

test "Parser - multiple spaces" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("arg1    arg2     arg3");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqualStrings("arg1", result[0]);
    try testing.expectEqualStrings("arg2", result[1]);
    try testing.expectEqualStrings("arg3", result[2]);
}

test "Parser - parse error for unclosed quotes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    try testing.expectError(error.ParseError, p.parse("'unclosed quote"));
    try testing.expectError(error.ParseError, p.parse("\"unclosed quote"));
}

test "Parser - complex parsing" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("command 'arg with spaces' \"another arg\" simple_arg 'quoted \"nested\" arg'");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 5), result.len);
    try testing.expectEqualStrings("command", result[0]);
    try testing.expectEqualStrings("arg with spaces", result[1]);
    try testing.expectEqualStrings("another arg", result[2]);
    try testing.expectEqualStrings("simple_arg", result[3]);
    try testing.expectEqualStrings("quoted \"nested\" arg", result[4]);
}

test "Parser - consecutive quotes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    // Test double quotes version
    const result1 = try p.parse("\"script  hello\"  \"world\"\"example\"");
    defer {
        for (result1) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result1);
    }
    try testing.expectEqual(@as(usize, 2), result1.len);
    try testing.expectEqualStrings("script  hello", result1[0]);
    try testing.expectEqualStrings("worldexample", result1[1]);

    // Test single quotes version
    const result2 = try p.parse("'script  hello'  'world''example'");
    defer {
        for (result2) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result2);
    }
    try testing.expectEqual(@as(usize, 2), result2.len);
    try testing.expectEqualStrings("script  hello", result2[0]);
    try testing.expectEqualStrings("worldexample", result2[1]);

    // Test mixed quotes version
    const result3 = try p.parse("\"script  hello\"  'world'\"example\"");
    defer {
        for (result3) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result3);
    }
    try testing.expectEqual(@as(usize, 2), result3.len);
    try testing.expectEqualStrings("script  hello", result3[0]);
    try testing.expectEqualStrings("worldexample", result3[1]);
}

test "Parser - memory management" {
    var p = Parser.init(testing.allocator);

    // Test multiple parse calls don't leak memory
    const result1 = try p.parse("test1 test2");
    defer {
        for (result1) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result1);
    }
    const result2 = try p.parse("test3 test4");
    defer {
        for (result2) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result2);
    }
    try testing.expectEqual(@as(usize, 2), result2.len);

    p.deinit();
}

test "Parser - escaped single quotes and backslashes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("\"world'hello'\\'shell\"");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqualStrings("world'hello'\\'shell", result[0]);
}

test "Parser - escaped double quotes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("\"world\\\"insidequotes\"hello\\\"");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqualStrings("world\"insidequoteshello\"", result[0]);
}

test "Parser - mixed quotes with escapes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("\"mixed\\\"quote'test'\\\\\"");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqualStrings("mixed\"quote'test'\\", result[0]);
}

test "Parser - complex path with spaces and escapes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("\"/tmp/baz/'f 34'\" \"/tmp/baz/'f  \\81'\" \"/tmp/baz/'f \\4\\'\"");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqualStrings("/tmp/baz/'f 34'", result[0]);
    try testing.expectEqualStrings("/tmp/baz/'f  \\81'", result[1]);
    try testing.expectEqualStrings("/tmp/baz/'f \\4\\'", result[2]);
}

test "Parser - multiple spaces with escapes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("example\\ \\ \\ \\ \\ \\ hello");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqualStrings("example      hello", result[0]);
}

test "Parser - escaped n character" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("script\\ntest");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqualStrings("scriptntest", result[0]);
}

test "Parser - escaped quotes within single quotes" {
    var p = Parser.init(testing.allocator);
    defer p.deinit();

    const result = try p.parse("\\'\\\"hello script\\\"\\\'");
    defer {
        for (result) |arg| {
            testing.allocator.free(arg);
        }
        testing.allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 2), result.len);
    try testing.expectEqualStrings("'\"hello", result[0]);
    try testing.expectEqualStrings("script\"'", result[1]);
}
