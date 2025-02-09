const std = @import("std");

pub const ExecLookup = struct {
    map: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .map = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn populate(self: *Self) !void {
        try self.scanPathDirs();
    }

    fn addExecutable(self: *Self, name: []const u8, path: []const u8) !void {
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);

        const value = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(value);

        if (self.map.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.map.put(key, value);
    }

    fn getPathEnvAlloc(self: *Self) ![]const u8 {
        var env_map = try std.process.getEnvMap(self.allocator);
        defer env_map.deinit();
        const result = try self.allocator.dupe(u8, env_map.get("PATH") orelse "");
        errdefer self.allocator.free(result);
        return result;
    }

    fn isExecutable(file: std.fs.File) !bool {
        const stat = try file.stat();
        return (stat.mode & 0b001) != 0;
    }

    fn processEntry(
        self: *Self,
        dir: std.fs.Dir,
        entry: std.fs.Dir.Entry,
    ) !void {
        if (entry.kind != .file) return;

        const abs_path = dir.realpathAlloc(self.allocator, entry.name) catch return;
        defer self.allocator.free(abs_path);

        const file = std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch return;
        defer file.close();

        if (try isExecutable(file)) {
            try self.addExecutable(entry.name, abs_path);
        }
    }

    fn scanDir(self: *Self, dir_path: []const u8) !void {
        if (!std.fs.path.isAbsolute(dir_path)) return;

        var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch return;
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            try self.processEntry(dir, entry);
        }
    }

    fn scanPathDirs(self: *Self) !void {
        const path_value = try self.getPathEnvAlloc();
        defer self.allocator.free(path_value);
        var dir_it = std.mem.split(u8, path_value, ":");

        while (dir_it.next()) |dir_path| {
            try self.scanDir(dir_path);
        }
    }

    pub fn getExecutablePath(self: Self, name: []const u8) ?[]const u8 {
        return self.map.get(name);
    }

    pub fn hasExecutable(self: Self, name: []const u8) bool {
        return self.map.contains(name);
    }

    pub fn iterator(self: Self) std.StringHashMap([]const u8).Iterator {
        return self.map.iterator();
    }
};

pub const Arguments = struct {
    args: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .args = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Self, input: []const u8) !void {
        self.clear();

        var in_word = false;
        var start: usize = 0;

        for (input, 0..) |char, i| {
            if (char == ' ') {
                if (in_word) {
                    const arg = try self.allocator.dupe(u8, input[start..i]);
                    errdefer self.allocator.free(arg);
                    try self.args.append(arg);
                    in_word = false;
                }
            } else if (!in_word) {
                start = i;
                in_word = true;
            }

            if (i == input.len - 1 and in_word) {
                const arg = try self.allocator.dupe(u8, input[start..input.len]);
                errdefer self.allocator.free(arg);
                try self.args.append(arg);
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
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        self.args.deinit();
    }
};
