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

    // ArrayList for storing command arguments
    var argv = std.ArrayList([]const u8).init(allocator);
    defer {
        // Free all stored strings
        for (argv.items) |arg| {
            allocator.free(arg);
        }
        argv.deinit();
    }

    // Exec lookup
    var lookup = try utils.createExecLookup(allocator);
    defer lookup.deinit();

    while (true) {
        try stdout.print("$ ", .{});

        // Clear previous input and arguments
        buffer.clearRetainingCapacity();
        argv.clearRetainingCapacity();

        // Read user input
        const stdin = std.io.getStdIn().reader();
        try stdin.streamUntilDelimiter(buffer.writer(), '\n', null);
        const user_input = buffer.items;

        // Parse input into arguments
        var in_word = false;
        var start: usize = 0;

        for (user_input, 0..) |character, index| {
            if (character == ' ') {
                if (in_word) {
                    const arg = try allocator.dupe(u8, user_input[start..index]);
                    try argv.append(arg);
                    in_word = false;
                }
            } else if (!in_word) {
                start = index;
                in_word = true;
            }

            if (index == user_input.len - 1 and in_word) {
                const arg = try allocator.dupe(u8, user_input[start..user_input.len]);
                try argv.append(arg);
            }
        }

        defer {
            for (argv.items) |arg| {
                allocator.free(arg);
            }
        }

        if (argv.items.len == 0) continue;

        const command = std.meta.stringToEnum(Builtins, argv.items[0]) orelse {
            try stdout.print("{s}: command not found\n", .{argv.items[0]});
            continue;
        };

        switch (command) {
            .exit => {
                if (commands.exitHandler(argv.items.len, argv.items) == 0) {
                    return;
                }
            },
            .echo => {
                _ = commands.echoHandler(argv.items.len, argv.items, stdout);
            },
            .type => {
                if (argv.items.len != 2) continue;
                const target = argv.items[1];
                _ = std.meta.stringToEnum(Builtins, target) orelse {
                    const target_path = lookup.get(target) orelse {
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
