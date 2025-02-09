const std = @import("std");
const utils = @import("utils.zig");

pub fn exitHandler(argc: usize, argv: []const []const u8) u8 {
    if (argc != 2) return 1;

    if (utils.strcmp("0", argv[1])) {
        return 0;
    } else {
        return 1;
    }
}

pub fn echoHandler(argc: usize, argv: []const []const u8, writer: std.fs.File.Writer) u8 {
    for (argv[1..argc], 0..) |word, index| {
        if (index != 0)
            writer.print(" ", .{}) catch {
                return 1;
            };

        writer.print("{s}", .{word}) catch {
            return 1;
        };
    }
    writer.print("\n", .{}) catch {
        return 1;
    };
    return 0;
}

pub fn typeHandler(allocator: std.mem.Allocator, argc: usize, argv: []const []const u8, writer: std.fs.File.Writer) u8 {
    if (argc != 2) return 1;

    var env_vars = std.process.getEnvMap(allocator) catch {
        return 1;
    };
    defer env_vars.deinit();
    const path_value = env_vars.get("PATH") orelse "";

    var iterator = std.mem.split(u8, path_value, ":");
    while (iterator.next()) |directory| {
        const aboslute_path = std.fs.path.join(allocator, &[_][]const u8{ directory, argv[1] }) catch {
            continue;
        };
        defer allocator.free(aboslute_path);

        const file = std.fs.openFileAbsolute(aboslute_path, .{ .mode = .read_only }) catch {
            continue;
        };
        defer file.close();

        const stats = file.stat() catch {
            continue;
        };
        const is_executable = stats.mode & 0b001 != 0;

        if (is_executable) {
            writer.print("{s} is {s}\n", .{ argv[1], aboslute_path }) catch {
                return 1;
            };
            return 0;
        }
    }
    return 1;
}
