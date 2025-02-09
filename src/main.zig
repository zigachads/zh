const std = @import("std");
const commands = @import("commands.zig");
const utils = @import("utils.zig");

const Builtins = enum { exit, echo, type };

pub fn main() !void {
    // Initialize GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // stdout and buffer
    const stdout = std.io.getStdOut().writer();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    // Argv
    var arguments = utils.Arguments.init(allocator);
    defer arguments.deinit();

    // ExecLookup
    var exec_lookup = utils.ExecLookup.init(allocator);
    defer exec_lookup.deinit();
    try exec_lookup.populate();

    while (true) {
        try stdout.print("$ ", .{});

        // Clear previous input and arguments
        buffer.clearRetainingCapacity();

        // Read user input
        const stdin = std.io.getStdIn().reader();
        try stdin.streamUntilDelimiter(buffer.writer(), '\n', null);
        const user_input = buffer.items;

        try arguments.parse(user_input);

        if (arguments.argc() == 0) continue;
        const items = arguments.argv().*;

        const command = std.meta.stringToEnum(Builtins, items[0]) orelse {
            try stdout.print("{s}: command not found\n", .{items[0]});
            continue;
        };

        switch (command) {
            .exit => {
                if (commands.exitHandler(items) == 0) {
                    return;
                }
            },
            .echo => {
                _ = commands.echoHandler(items, stdout);
            },
            .type => {
                if (items.len != 2) continue;
                const target = items[1];
                _ = std.meta.stringToEnum(Builtins, target) orelse {
                    const target_path = exec_lookup.getExecutablePath(target) orelse {
                        try stdout.print("{s}: not found\n", .{target});
                        continue;
                    };
                    try stdout.print("{s} is {s}\n", .{ target, target_path });
                    continue;
                };
                try stdout.print("{s} is a shell builtin\n", .{target});
            },
        }
    }
}
