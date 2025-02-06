const std = @import("std");

fn strcmp(str1: []const u8, str2: []const u8) bool {
    if (str1.len != str2.len) return false;
    for (str1, str2) |c1, c2| {
        if (c1 != c2) return false;
    }
    return true;
}

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

        const command = argv[0];
        if (argc == 2 and strcmp("exit", command) and strcmp("0", argv[1])) {
            return;
        } else if (argc > 1 and strcmp("echo", command)) {
            for (argv[1..argc], 0..) |word, index| {
                if (index != 0) try stdout.print(" ", .{});
                try stdout.print("{s}", .{word});
            }
            try stdout.print("\n", .{});
            continue;
        }

        try stdout.print("{s}: command not found\n", .{user_input});
    }
}
