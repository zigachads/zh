const std = @import("std");
const utils = @import("utils.zig");

pub fn exitHandler(argc: u32, argv: []const []const u8, _: std.fs.File.Writer) u8 {
    if (argc != 2) return 1;

    if (utils.strcmp("0", argv[1])) {
        return 0;
    } else {
        return 1;
    }
}

pub fn echoHandler(argc: u32, argv: []const []const u8, stdout: std.fs.File.Writer) u8 {
    for (argv[1..argc], 0..) |word, index| {
        if (index != 0)
            stdout.print(" ", .{}) catch {
                return 1;
            };

        stdout.print("{s}", .{word}) catch {
            return 1;
        };
    }
    stdout.print("\n", .{}) catch {
        return 1;
    };
    return 0;
}
