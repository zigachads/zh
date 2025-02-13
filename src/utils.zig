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
