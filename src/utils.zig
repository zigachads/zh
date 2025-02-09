const std = @import("std");

pub fn createExecLookup(allocator: std.mem.Allocator) !std.hash_map.StringHashMap([]const u8) {
    var env_vars = try std.process.getEnvMap(allocator);
    defer env_vars.deinit();

    const path_value = env_vars.get("PATH") orelse "";
    var dir_str_it = std.mem.split(u8, path_value, ":");

    var lookup = std.hash_map.StringHashMap([]const u8).init(allocator);
    errdefer lookup.deinit();

    while (dir_str_it.next()) |dir_str| {
        if (!std.fs.path.isAbsolute(dir_str)) continue;
        var dir = std.fs.openDirAbsolute(dir_str, .{ .iterate = true }) catch {
            continue;
        };
        defer dir.close();
        var dir_it = dir.iterate();

        while (try dir_it.next()) |entry| {
            if (entry.kind != std.fs.File.Kind.file) continue;

            const abs_path = dir.realpathAlloc(allocator, entry.name) catch {
                continue;
            };
            errdefer allocator.free(abs_path);

            const file = std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch {
                continue;
            };
            defer file.close();

            const stats = file.stat() catch {
                continue;
            };

            if (stats.mode & 0b001 != 0) {
                const exec_name = try allocator.dupe(u8, entry.name);
                errdefer allocator.free(exec_name);

                try lookup.put(exec_name, abs_path);
            }
        }
    }

    return lookup;
}
