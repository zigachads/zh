const std = @import("std");
const utils = @import("utils.zig");

pub const Builtins = enum { exit, echo, type, pwd, cd };
pub const BuiltinAction = enum { panic_quit, peace_quit, none };

pub fn exitHandler(argv: []const []const u8, writer: std.fs.File.Writer) std.fs.File.WriteError!BuiltinAction {
    if (argv.len != 2) {
        try writer.print("exit: arguments number mismatch, {d} vs 2\n", .{argv.len});
        return .none;
    }
    const arg = std.fmt.parseInt(u8, argv[1], 10) catch {
        try writer.print("exit: invalid argument: {s}\n", .{argv[1]});
        return .none;
    };
    if (arg == 0) {
        return .peace_quit;
    } else {
        return .panic_quit;
    }
}

pub fn echoHandler(argv: []const []const u8, writer: std.fs.File.Writer) !BuiltinAction {
    for (argv[1..argv.len], 0..) |word, index| {
        if (index != 0)
            try writer.print(" ", .{});
        try writer.print("{s}", .{word});
    }
    try writer.print("\n", .{});
    return .none;
}

pub fn typeHandler(argv: []const []const u8, exec_lookup: utils.ExecLookup, writer: std.fs.File.Writer) !BuiltinAction {
    if (argv.len != 2) {
        try writer.print("type: arguments number mismatch, {d} vs 2\n", .{argv.len});
        return .none;
    }
    const target = argv[1];
    _ = std.meta.stringToEnum(Builtins, target) orelse {
        const target_path = exec_lookup.getExecutablePath(target) orelse {
            try writer.print("{s}: not found\n", .{target});
            return .none;
        };
        try writer.print("{s} is {s}\n", .{ target, target_path });
        return .none;
    };
    try writer.print("{s} is a shell builtin\n", .{target});
    return .none;
}

pub fn pwdHandler(allocator: std.mem.Allocator, argv: []const []const u8, writer: std.fs.File.Writer) !BuiltinAction {
    if (argv.len != 1) {
        try writer.print("pwd: argument is not needed\n", .{});
        return .none;
    }
    const pwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(pwd);
    try writer.print("{s}\n", .{pwd});
    return .none;
}

pub fn cdHandler(allocator: std.mem.Allocator, argv: []const []const u8, writer: std.fs.File.Writer) !BuiltinAction {
    if (argv.len != 2) {
        try writer.print("cd: arguments number mismatch, {d} vs 2\n", .{argv.len});
        return .none;
    }

    var dir: ?std.fs.Dir = null;
    defer {
        if (dir) |*d| {
            d.*.close();
        }
    }

    const target = argv[1];
    if (target[0] != '~') {
        dir = std.fs.cwd().openDir(target, .{}) catch {
            try writer.print("cd: {s}: No such file or directory\n", .{target});
            return .none;
        };
    } else {
        var env_map = std.process.getEnvMap(allocator) catch {
            return .none;
        };
        defer env_map.deinit();

        const home = env_map.get("HOME") orelse {
            try writer.print("cd: HOME variable not available\n", .{});
            return .none;
        };

        if (target.len > 1) {
            const path = std.fs.path.join(allocator, &[_][]const u8{ home, target[1..] }) catch {
                try writer.print("cd: {s}: No such file or directory\n", .{target});
                return .none;
            };
            defer allocator.free(path);
            dir = std.fs.cwd().openDir(path, .{}) catch {
                try writer.print("cd: {s}: No such file or directory\n", .{target});
                return .none;
            };
        } else {
            dir = std.fs.cwd().openDir(home, .{}) catch {
                try writer.print("cd: {s}: No such file or directory\n", .{target});
                return .none;
            };
        }
    }

    if (dir) |*d| {
        d.*.setAsCwd() catch |err| {
            try writer.print("cd: {any}\n", .{err});
        };
    }

    return .none;
}
