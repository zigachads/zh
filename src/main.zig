const std = @import("std");
const builtins = @import("builtins.zig");
const utils = @import("utils.zig");
const parser = @import("parser.zig");

test {
    comptime {
        _ = @import("./test/tests.zig");
    }
}

fn childProcessHelper(allocator: std.mem.Allocator, argv: []const []const u8) !std.process.Child.Term {
    var child = std.process.Child.init(argv, allocator);

    return try child.spawnAndWait();
}

pub fn main() !u8 {
    // Initialize GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // stdout and buffer
    const stdout = std.io.getStdOut().writer();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    // Argv
    var _parser = parser.Parser.init(allocator);
    defer _parser.deinit();

    // ExecLookup
    var exec_lookup = utils.ExecLookup.init(allocator);
    defer exec_lookup.deinit();
    try exec_lookup.populate();

    // NOTE: implement pipe wtih a custom writer struct
    // for childprocess use collectOutput

    while (true) {
        try stdout.print("$ ", .{});

        // Clear previous input and arguments
        buffer.clearRetainingCapacity();

        // Read user input
        const stdin = std.io.getStdIn().reader();
        try stdin.streamUntilDelimiter(buffer.writer(), '\n', null);
        const user_input = buffer.items;

        const argv = _parser.parse(user_input) catch {
            try stdout.print("zshell: parse error\n", .{});
            continue;
        };
        defer {
            for (argv) |arg| {
                allocator.free(arg);
            }
            allocator.free(argv);
        }

        if (argv.len == 0) continue;

        const command = std.meta.stringToEnum(builtins.Builtins, argv[0]) orelse {
            if (exec_lookup.hasExecutable(argv[0])) {
                _ = childProcessHelper(allocator, argv) catch {};
            } else {
                try stdout.print("{s}: command not found\n", .{argv[0]});
            }
            continue;
        };

        switch (command) {
            .exit => {
                switch (try builtins.exitHandler(argv, stdout)) {
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
                _ = try builtins.echoHandler(argv, stdout);
            },
            .type => {
                _ = try builtins.typeHandler(argv, exec_lookup, stdout);
            },
            .pwd => {
                _ = try builtins.pwdHandler(allocator, argv, stdout);
            },
            .cd => {
                _ = try builtins.cdHandler(allocator, argv, stdout);
            },
        }
    }

    return 0;
}
