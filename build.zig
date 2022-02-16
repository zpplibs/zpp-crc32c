const std = @import("std");
const deps = @import("deps.zig");

const mode_names = blk: {
    const fields = @typeInfo(std.builtin.Mode).Enum.fields;
    var names: [fields.len][]const u8 = undefined;
    inline for (fields) |field, i| names[i] = "[ " ++ field.name ++ " ] ";
    break :blk names;
};
var mode_name_idx: usize = undefined;
// comptime options
var build_options: *std.build.OptionsStep = undefined;

const c_flags = &[_][]const u8{ "-std=c99" };

fn addTest(
    comptime root_src: []const u8,
    test_name: []const u8,
    b: *std.build.Builder,
) *std.build.LibExeObjStep {
    const t = b.addTest(root_src);
    t.setNamePrefix(mode_names[mode_name_idx]);
    
    b.step(
        if (test_name.len != 0) test_name else "test:" ++ root_src,
        "Run tests from " ++ root_src,
    ).dependOn(&t.step);
    
    return t;
}

fn addExecutable(
    comptime name: []const u8,
    root_src: []const u8,
    run_name: []const u8,
    run_description: []const u8,
    b: *std.build.Builder,
) *std.build.LibExeObjStep {
    const is_zig = std.mem.endsWith(u8, root_src, ".zig");
    const exe = b.addExecutable(name, if (is_zig) root_src else null);
    if (is_zig) exe.addOptions("build_options", build_options)
    else exe.addCSourceFile(root_src, c_flags);
    
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    
    b.step(
        if (run_name.len != 0) run_name else "run:" ++ name,
        if (run_description.len != 0) run_description else "Run " ++ name,
    ).dependOn(&run_cmd.step);
    
    return exe;
}

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    mode_name_idx = @enumToInt(mode);
    
    // options
    const version: []const u8 = b.option(
        []const u8, "version", "the app version",
    ) orelse parseGitRevHead(b.allocator) catch "master";
    
    // will not be used/referenced after the surrounding function returns
    build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);
    
    // tests
    const test_all = b.step("test", "Run all tests");
    const tests = &[_]*std.build.LibExeObjStep{
        deps.addAllTo(
            addTest("src/lib.zig", "test:lib", b),
            b, target, mode,
        ),
    };
    for (tests) |t| test_all.dependOn(&t.step);
    
    // executables
    deps.addAllTo(
        addExecutable(
            "crc32c_capi_unittest", "crc32c/src/crc32c_capi_unittest.c",
            "", "Run the crc32c c api unit tests",
            b,
        ),
        b, target, mode,
    ).install();
    deps.addAllTo(
        addExecutable(
            "zpp-crc32c-c", "src/example.c",
            "run-c", "Run the crc32c c example",
            b,
        ),
        b, target, mode,
    ).install();
    deps.addAllTo(
        addExecutable(
            "zpp-crc32c", "src/example.zig",
            "run", "Run the crc32c example",
            b,
        ),
        b, target, mode,
    ).install();
}

/// Returns the output of `git rev-parse HEAD`
pub fn parseGitRevHead(a: std.mem.Allocator) ![]const u8 {
    const max = std.math.maxInt(usize);
    const git_dir = try std.fs.cwd().openDir(".git", .{});
    // content of `.git/HEAD` -> `ref: refs/heads/master`
    const h = std.mem.trim(u8, try git_dir.readFileAlloc(a, "HEAD", max), "\n");
    // content of `refs/heads/master`
    return std.mem.trim(u8, try git_dir.readFileAlloc(a, h[5..], max), "\n");
}
