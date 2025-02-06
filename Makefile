zig-out/bin/main:
	zig build

run: zig-out/bin/main
	./zig-out/bin/main $(ARGS)

debug: zig-out/bin/main
	lldb zig-out/bin/main
