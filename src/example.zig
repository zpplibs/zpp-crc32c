const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

const crc32c = @import("zpp-crc32c");

fn printVersion() void {
    std.debug.print("zpp-crc32c {s} {s} {s}", .{
        build_options.version,
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
    });
}

pub fn main() !void {
    const a = std.heap.c_allocator;
    const args = try std.process.argsAlloc(a);
    defer a.free(args);
    
    if (args.len == 1) {
        std.debug.print(
            \\1st arg(text) is required.
            \\This will print the crc32c checksum of the args.
            \\
            \\
            ,.{}
        );
        printVersion();
        return;
    }
    
    var result = crc32c.value(args[1]);
    for (args[2..]) |arg| result = crc32c.extend(result, arg);
    std.debug.print("{}\n", .{ result });
}