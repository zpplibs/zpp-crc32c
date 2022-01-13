const std = @import("std");

const c = @cImport({
    @cInclude("crc32c/crc32c.h");
});

pub fn extend(crc: u32, data: []const u8) u32 {
    return c.crc32c_extend(crc, data.ptr, data.len);
}

pub fn value(data: []const u8) u32 {
    return c.crc32c_value(data.ptr, data.len);
}

test "lib" {
    const result = value("foo");
    try std.testing.expect(0 != result);
    const extended = extend(result, "bar");
    try std.testing.expect(0 != extended);

    std.debug.print(
        "ok\n  - crc32c.value(foo): {}\n  - crc32c.extend(foo, bar): {}\n",
        .{ result, extended },
    );
}
