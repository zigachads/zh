SRC_FILES := $(wildcard src/*.zig)

zig-out/bin/main: $(SRC_FILES)
	zig build

run: zig-out/bin/main
	zig build run

test: $(SRC_FILES)
	zig build test --summary all

debug: zig-out/bin/main
	lldb zig-out/bin/main
