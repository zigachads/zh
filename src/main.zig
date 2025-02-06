const std = @import("std");
const utils = @import("utils.zig");
const commands = @import("commands.zig");

const Builtins = enum { exit, echo, type };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    while (true) {
        try stdout.print("$ ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var argc: u32 = 0;
        var argv: [16][]const u8 = undefined;
        var in_word = false;
        var start: usize = 0;

        for (user_input, 0..) |character, index| {
            if (character == ' ') {
                if (in_word) {
                    argv[argc] = user_input[start..index];
                    argc += 1;
                    in_word = false;
                }
            } else if (!in_word) {
                start = index;
                in_word = true;
            }

            if (index == user_input.len - 1 and in_word) {
                argv[argc] = user_input[start..user_input.len];
                argc += 1;
            }

            if (argc == argv.len) return;
        }

        if (argc == 0) continue;

        const command = std.meta.stringToEnum(Builtins, argv[0]) orelse {
            try stdout.print("{s}: command not found\n", .{argv[0]});
            continue;
        };
        switch (command) {
            .exit => {
                if (commands.exitHandler(argc, &argv, stdout) == 0) {
                    return;
                }
            },
            .echo => {
                _ = commands.echoHandler(argc, &argv, stdout);
            },
            .type => {
                if (argc != 2) continue;
                _ = std.meta.stringToEnum(Builtins, argv[1]) orelse {
                    try stdout.print("{s}: not found\n", .{argv[1]});
                    continue;
                };
                try stdout.print("{s} is a shell builtin\n", .{argv[1]});
            },
        }
    }
}
