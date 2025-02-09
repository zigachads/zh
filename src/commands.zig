const std = @import("std");
const utils = @import("utils.zig");

pub fn exitHandler(argc: usize, argv: []const []const u8) u8 {
    if (argc != 2) return 1;

    if (std.mem.eql(u8, "0", argv[1])) {
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
