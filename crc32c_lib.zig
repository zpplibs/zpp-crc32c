const std = @import("std");

pub fn configure(
    comptime basedir: []const u8,
    comptime dep_dirs: anytype,
    comptime root_dep_dirs: anytype,
    allocator: std.mem.Allocator,
    lib: *std.build.LibExeObjStep,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
) *std.build.LibExeObjStep {
    _ = dep_dirs;
    _ = root_dep_dirs;
    _ = allocator;
    
    lib.setTarget(target);
    lib.setBuildMode(mode);
    
    lib.linkLibC();
    lib.linkLibCpp();
    
    lib.addIncludeDir(basedir ++ "/crc32c/include");
    lib.addIncludeDir(basedir ++ "/crc32c/config-include");
    
    const flags = &[_][]const u8{
        "-std=c++14",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-fno-exceptions",
        "-fno-rtti",
        "-DNDEBUG",
        "-DHAVE_ARM64_CRC32C=0", // TODO conditionally enable this when zig clang arm64 bug is fixed
    };
    lib.addCSourceFiles(&.{
        basedir ++ "/crc32c/src/crc32c_portable.cc",
        basedir ++ "/crc32c/src/crc32c.cc",
    }, flags);
    // TODO restore this when zig clang arm64 bug is fixed
    // if (
    //     std.Target.Os.Tag.macos == target.getOsTag() and
    //     std.Target.Cpu.Arch.aarch64 == target.getCpuArch()
    // ) {
    //     lib.addCSourceFile(basedir ++ "/crc32c/src/crc32c_arm64.cc", flags);
    // }
    
    return lib;
}
