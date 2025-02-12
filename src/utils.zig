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
        if (entry.kind != .file and entry.kind != .sym_link) return;

        const real_path = try dir.realpathAlloc(self.allocator, entry.name);
        defer self.allocator.free(real_path);

        const file = try std.fs.openFileAbsolute(real_path, .{ .mode = .read_only });
        defer file.close();

        if (try isExecutable(file)) {
            if (entry.kind == .file) {
                try self.addExecutable(entry.name, real_path);
            } else {
                const dir_path = try dir.realpathAlloc(self.allocator, ".");
                defer self.allocator.free(dir_path);
                const concat_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, entry.name });
                defer self.allocator.free(concat_path);
                try self.addExecutable(entry.name, concat_path);
            }
        }
    }

    fn scanDir(self: *Self, dir_path: []const u8) !void {
        if (!std.fs.path.isAbsolute(dir_path)) return;

        var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch return;
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            self.processEntry(dir, entry) catch {
                continue;
            };
        }
    }

    fn scanPathDirs(self: *Self) !void {
        const path_value = try self.getPathEnvAlloc();
        defer self.allocator.free(path_value);
        var dir_it = std.mem.split(u8, path_value, ":");

        while (dir_it.next()) |dir_path| {
            self.scanDir(dir_path) catch {
                continue;
            };
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

pub fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        top: ?T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .items = std.ArrayList(T).init(allocator), .top = null };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn push(self: *Self, item: T) !void {
            try self.items.append(item);
            self.top = item;
        }

        pub fn pop(self: *Self) ?T {
            if (self.isEmpty()) return null;
            const result = self.items.pop();
            if (!self.isEmpty()) {
                self.top = self.items.getLast();
            } else {
                self.top = null;
            }
            return result;
        }

        pub fn isEmpty(self: *Self) bool {
            return self.items.items.len == 0;
        }

        pub fn clear(self: *Self) void {
            while (!self.isEmpty()) {
                _ = self.pop();
            }
        }

        pub fn size(self: *Self) usize {
            return self.items.items.len;
        }
    };
}

pub fn fifoToOwnedArrayList(fifo: *std.io.PollFifo) std.ArrayList(u8) {
    if (fifo.head > 0) {
        @memcpy(fifo.buf[0..fifo.count], fifo.buf[fifo.head..][0..fifo.count]);
    }
    const result = std.ArrayList(u8){
        .items = fifo.buf[0..fifo.count],
        .capacity = fifo.buf.len,
        .allocator = fifo.allocator,
    };
    fifo.* = std.io.PollFifo.init(fifo.allocator);
    return result;
}
