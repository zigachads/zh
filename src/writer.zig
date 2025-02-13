const std = @import("std");

pub const Writer = struct {
    _file: ?std.fs.File = null,
    _default_file_getter: *const fn () std.fs.File,
    writer: std.fs.File.Writer,

    const Self = @This();

    pub fn init(default_file_getter: *const fn () std.fs.File) Self {
        const f = default_file_getter();
        return Self{
            ._file = null,
            ._default_file_getter = default_file_getter,
            .writer = f.writer(),
        };
    }

    pub fn to_default(self: *Self) bool {
        if (self._file) |f| {
            f.close();
            self._file = null;
            const df = self._default_file_getter();
            self.writer = df.writer();
            return true;
        } else {
            return false;
        }
    }

    pub fn to_file(self: *Self, path: []const u8, try_append: bool) bool {
        if (self._file) |f| {
            f.close();
            self._file = null;
        }

        var try_create = false;

        const file_open_flags: std.fs.File.OpenFlags = .{ .mode = .read_write };
        if (if (std.fs.path.isAbsolute(path)) std.fs.openFileAbsolute(
            path,
            file_open_flags,
        ) else std.fs.cwd().openFile(
            path,
            file_open_flags,
        )) |f| {
            if (try_append) f.seekFromEnd(0) catch {
                f.close();
                return false;
            };
            self._file = f;
        } else |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                try_create = true;
            } else {
                return false;
            }
        }

        if (!try_create) {
            self.writer = self._file.?.writer();
            return true;
        }

        const file_create_flags: std.fs.File.CreateFlags = .{ .read = true };
        if (std.fs.path.isAbsolute(path)) {
            if (std.fs.createFileAbsolute(path, file_create_flags)) |f| {
                self._file = f;
            } else |_| {
                return false;
            }
        } else {
            if (std.fs.cwd().createFile(path, file_create_flags)) |f| {
                self._file = f;
            } else |_| {
                return false;
            }
        }
        self.writer = self._file.?.writer();
        return true;
    }

    pub fn is_default(self: *Self) bool {
        return self._file == null;
    }

    pub fn deinit(self: *Self) void {
        if (self._file) |f| {
            f.close();
        }
    }
};
