const std = @import("std");
const crc32c = @import("zpp-crc32c");

pub fn main() void {
    const a = std.heap.c_allocator;
    const args = std.process.argsAlloc(a) catch return;
    defer a.free(args);
    
    if (args.len == 1) {
        std.debug.print("1st arg is required.\n", .{});
        return;
    }
    
    const result = crc32c.value(args[1]);
    std.debug.print("{}\n", .{ result });
}