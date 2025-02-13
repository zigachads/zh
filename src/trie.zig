const std = @import("std");

pub const Trie = struct {
    const Node = struct {
        children: std.AutoHashMap(u8, *Node),
        is_end: bool,

        fn init(allocator: std.mem.Allocator) !*Node {
            const node = try allocator.create(Node);
            node.* = .{
                .children = std.AutoHashMap(u8, *Node).init(allocator),
                .is_end = false,
            };
            return node;
        }

        fn deinit(self: *Node, allocator: std.mem.Allocator) void {
            var it = self.children.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.*.deinit(allocator);
                allocator.destroy(entry.value_ptr.*);
            }
            self.children.deinit();
        }
    };

    root: *Node,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .root = try Node.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.root.deinit(self.allocator);
        self.allocator.destroy(self.root);
    }

    pub fn insert(self: *Self, word: []const u8) !void {
        var current = self.root;

        for (word) |c| {
            if (!current.children.contains(c)) {
                const new_node = try Node.init(self.allocator);
                try current.children.put(c, new_node);
            }
            current = current.children.get(c).?;
        }
        current.is_end = true;
    }

    pub fn findWithPrefix(self: *Self, prefix: []const u8) !std.ArrayList([]const u8) {
        var results = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (results.items) |result| {
                self.allocator.free(result);
            }
            results.deinit();
        }
        var current = self.root;

        for (prefix) |c| {
            if (!current.children.contains(c)) {
                return results;
            }
            current = current.children.get(c).?;
        }

        var word_buffer = std.ArrayList(u8).init(self.allocator);
        defer word_buffer.deinit();

        try word_buffer.appendSlice(prefix);

        try self.dfs(current, &word_buffer, &results);

        return results;
    }

    fn dfs(
        self: *Self,
        node: *Node,
        word_buffer: *std.ArrayList(u8),
        results: *std.ArrayList([]const u8),
    ) !void {
        if (node.is_end) {
            const word = try self.allocator.dupe(u8, word_buffer.items);
            errdefer self.allocator.free(word);
            try results.append(word);
        }

        var it = node.children.iterator();
        while (it.next()) |entry| {
            const c = entry.key_ptr.*;
            try word_buffer.append(c);
            try self.dfs(entry.value_ptr.*, word_buffer, results);
            _ = word_buffer.pop();
        }
    }
};
