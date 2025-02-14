const std = @import("std");
const testing = std.testing;

const Trie = @import("../trie.zig");

fn verifyResults(results: []const []const u8, expected: []const []const u8) !void {
    try testing.expectEqual(expected.len, results.len);

    var found = false;
    for (results) |result| {
        found = false;
        for (expected) |exp| {
            if (std.mem.eql(u8, result, exp)) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
    }
}

test "Trie - basic prefix search" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("cat");
    try t.insert("car");
    try t.insert("card");
    try t.insert("cart");
    try t.insert("dog");

    const results = try t.findWithPrefix("car");
    const expected = [_][]const u8{ "car", "card", "cart" };
    try verifyResults(results, &expected);
}

test "Trie - empty prefix search" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("cat");
    try t.insert("car");
    try t.insert("card");
    try t.insert("cart");
    try t.insert("dog");

    const results = try t.findWithPrefix("");
    const expected = [_][]const u8{ "cat", "car", "card", "cart", "dog" };
    try verifyResults(results, &expected);
}

test "Trie - non-existent prefix" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("cat");
    try t.insert("dog");

    const results = try t.findWithPrefix("xyz");
    try testing.expectEqual(@as(usize, 0), results.len);
}

test "Trie - case sensitivity" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("CAT");
    try t.insert("Cat");
    try t.insert("cat");

    const results = try t.findWithPrefix("C");
    const expected = [_][]const u8{ "CAT", "Cat" };
    try verifyResults(results, &expected);
}

test "Trie - special characters" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("hello!");
    try t.insert("hello?");
    try t.insert("hello...");

    const results = try t.findWithPrefix("hello");
    const expected = [_][]const u8{ "hello!", "hello?", "hello..." };
    try verifyResults(results, &expected);
}

test "Trie - numbers in words" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("test1");
    try t.insert("test2");
    try t.insert("test123");

    const results = try t.findWithPrefix("test");
    const expected = [_][]const u8{ "test1", "test2", "test123" };
    try verifyResults(results, &expected);
}

test "Trie - single character words" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    try t.insert("a");
    try t.insert("b");
    try t.insert("c");

    const results = try t.findWithPrefix("a");
    const expected = [_][]const u8{"a"};
    try verifyResults(results, &expected);
}

test "Trie - long words" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = try Trie.init(allocator);
    defer t.deinit();

    const long_word1 = "supercalifragilisticexpialidocious";
    const long_word2 = "supercalifragilisticexpialidociously";
    try t.insert(long_word1);
    try t.insert(long_word2);

    const results = try t.findWithPrefix("super");
    const expected = [_][]const u8{ long_word1, long_word2 };
    try verifyResults(results, &expected);
}
