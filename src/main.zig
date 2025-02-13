const std = @import("std");
const builtins = @import("builtins.zig");
const utils = @import("utils.zig");
const parser = @import("parser.zig");
const writer = @import("writer.zig");

test {
    comptime {
        _ = @import("./test/tests.zig");
    }
}

pub fn main() !u8 {
    // Initialize GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Buffer
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    // Argv
    var _parser = parser.Parser.init(allocator);
    defer _parser.deinit();

    // ExecLookup
    var exec_lookup = utils.ExecLookup.init(allocator);
    defer exec_lookup.deinit();
    try exec_lookup.populate();

    // Writer
    var stdout = writer.Writer.init(&std.io.getStdOut);
    var stderr = writer.Writer.init(&std.io.getStdOut);

    while (true) {
        // Writer reset
        _ = stdout.to_default();
        _ = stderr.to_default();

        // Prompt
        try stdout.writer.print("$ ", .{});

        // Clear previous input and arguments
        buffer.clearRetainingCapacity();

        // Read user input
        const stdin = std.io.getStdIn().reader();
        try stdin.streamUntilDelimiter(buffer.writer(), '\n', null);
        const user_input = buffer.items;

        const raw_argv = _parser.parse(user_input) catch {
            try stderr.writer.print("zshell: parse error\n", .{});
            continue;
        };
        defer {
            for (raw_argv) |arg| {
                allocator.free(arg);
            }
            allocator.free(raw_argv);
        }

        if (raw_argv.len == 0) continue;

        const argv = parser.redirectHandler(
            raw_argv,
            &stdout,
            &stderr,
        ) catch raw_argv;

        const command = std.meta.stringToEnum(builtins.Builtins, argv[0]) orelse {
            if (exec_lookup.hasExecutable(argv[0])) {
                _ = builtins.execHandler(allocator, argv, &stdout, &stderr) catch {};
            } else {
                try stderr.writer.print("{s}: command not found\n", .{argv[0]});
            }
            continue;
        };

        switch (command) {
            .exit => {
                switch (try builtins.exitHandler(argv, &stderr)) {
                    .none => {},
                    .peace_quit => {
                        return 0;
                    },
                    .panic_quit => {
                        return 1;
                    },
                }
            },
            .echo => {
                _ = try builtins.echoHandler(argv, &stdout);
            },
            .type => {
                _ = try builtins.typeHandler(argv, &exec_lookup, &stdout, &stderr);
            },
            .pwd => {
                _ = try builtins.pwdHandler(allocator, argv, &stdout, &stderr);
            },
            .cd => {
                _ = try builtins.cdHandler(allocator, argv, &stderr);
            },
        }
    }

    return 0;
}
