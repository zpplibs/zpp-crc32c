const std = @import("std");
const builtin = @import("builtin");

const SourceType = struct {
    with_exe: bool,
    with_test: bool,
    const both: SourceType = .{ .with_exe = true, .with_test = true };
    const exe_only: SourceType = .{ .with_exe = true, .with_test = false };
    const test_only: SourceType = .{ .with_exe = false, .with_test = true };
};

const BuildModule = struct {
    b: *std.Build,
    tests: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    optimize_idx: usize,
    // extra
    build_options: *std.Build.Module,
    c_flags: []const []const u8,
    cpp_flags: []const []const u8,
    test_filters: []const []const u8,
};

const optimize_names = blk: {
    // const fields = @typeInfo(std.builtin.OptimizeMode).Enum.fields;
    const fields = std.meta.fields(std.builtin.OptimizeMode);
    var names: [fields.len][]const u8 = undefined;
    for (fields, 0..) |field, i| names[i] = field.name;
    break :blk names;
};

const common_flags = &[_][]const u8{
    "-Wall",
    "-Wextra",
    "-Werror",
    "-DNDEBUG",
};

const c_flags = common_flags;
const cpp_flags = &[_][]const u8{
    "-fno-exceptions",
    "-fno-rtti",
} ++ common_flags;

const cpp_srcs = &[_][]const u8{
    "crc32c_portable.cc",
    "crc32c.cc",
};

const c_flags_def = c_flags ++ &[_][]const u8{
    "-DHAVE_ARM64_CRC32C=0",
};
const c_flags_arm64 = c_flags ++ &[_][]const u8{
    "-DHAVE_ARM64_CRC32C=1",
};
const cpp_flags_def = cpp_flags ++ &[_][]const u8{
    "-DHAVE_ARM64_CRC32C=0",
};
const cpp_flags_arm64 = cpp_flags ++ &[_][]const u8{
    "-DHAVE_ARM64_CRC32C=1",
};
const cpp_srcs_arm64 = cpp_srcs ++ &[_][]const u8{
    "crc32c_arm64.cc",
};

fn resolveSrcName(src: []const u8) []const u8 {
    const slash_idx = std.mem.lastIndexOf(u8, src, "/");
    const start = if (slash_idx) |idx| idx + 1 else 0;
    const dot_idx = std.mem.indexOf(
        u8,
        if (start == 0) src else src[start..],
        ".",
    ) orelse 0;
    return if (start != 0 and dot_idx != 0) src[start .. start + dot_idx] else src;
}

fn concat(b: *std.Build, prefix: []const u8, suffix: []const u8, def: []const u8) []const u8 {
    const out = b.allocator.alloc(u8, prefix.len + suffix.len) catch return def;
    @memcpy(out[0..prefix.len], prefix);
    @memcpy(out[prefix.len..], suffix);
    return out;
}

fn addModuleTo(
    bm: *const BuildModule,
    comptime source_type: SourceType,
    comptime root_src: []const u8,
    comptime run_name: []const u8,
) *std.Build.Module {
    const is_zig = std.mem.endsWith(u8, root_src, ".zig");

    if (!source_type.with_test and !source_type.with_exe) @panic("Must atleast be exe or test.");
    if (!is_zig and source_type.with_test) @panic("Tests can only be in .zig files");

    const name = comptime resolveSrcName(root_src);

    var b = bm.b;
    const mod = b.createModule(.{
        .root_source_file = if (!is_zig) null else .{
            .src_path = .{
                .owner = b,
                .sub_path = root_src,
            },
        },
        .target = bm.target,
        .optimize = bm.optimize,
    });

    if (is_zig) {
        mod.addImport("build_options", bm.build_options);
    }
    if (source_type.with_exe) {
        const exe_name = if (bm.optimize == .ReleaseFast) name else concat(b, name ++ "--", optimize_names[bm.optimize_idx], name);
        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_module = mod,
            .link_libc = !is_zig,
        });

        if (!is_zig) {
            const is_c = std.mem.endsWith(u8, root_src, ".c");
            exe.addCSourceFile(.{
                .file = .{ .src_path = .{
                    .owner = b,
                    .sub_path = root_src,
                } },
                .flags = if (is_c) bm.c_flags else bm.cpp_flags,
            });
            // exe.linkLibrary(lib);
            // exe.addIncludePath(b.path("crc32c/include"));
            // exe.addIncludePath(lib.getEmittedIncludeTree());
            if (is_c) {
                exe.linkLibC();
            } else {
                exe.linkLibCpp();
            }
        }
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);

        b.step(
            if (run_name.len != 0) run_name else "run:" ++ name,
            "Run executable from " ++ root_src,
        ).dependOn(&run_cmd.step);

        b.installArtifact(exe);
    }
    if (is_zig and source_type.with_test) {
        const prefix = name ++ "--test--";
        const test_name = concat(b, prefix, optimize_names[bm.optimize_idx], prefix);
        const t = b.addTest(.{
            .name = test_name,
            .root_module = mod,
            .filters = bm.test_filters,
        });

        b.step(
            "test:" ++ name,
            "Run tests from " ++ root_src,
        ).dependOn(&b.addRunArtifact(t).step);

        b.installArtifact(t);
        bm.tests.dependOn(&b.addRunArtifact(t).step);
    }
    return mod;
}

pub fn parseGitRevHead(a: std.mem.Allocator) ![]const u8 {
    var child = std.process.Child.init(
        &.{ "git", "rev-parse", "HEAD" },
        a,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    var child_stdout = try std.ArrayListUnmanaged(u8).initCapacity(
        a,
        50,
    );
    var child_stderr = std.ArrayListUnmanaged(u8).initBuffer(
        child_stdout.items,
    );
    try child.collectOutput(
        a,
        &child_stdout,
        &child_stderr,
        std.math.maxInt(usize),
    );
    _ = try child.wait();
    return std.mem.trim(u8, child_stdout.items, "\n");
}

pub fn addIncludePathsTo(
    t: *std.Build.Step.TranslateC,
    paths: []const std.Build.LazyPath,
) *std.Build.Step.TranslateC {
    for (paths) |p| t.addIncludePath(p);
    return t;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const arch = target.query.cpu_arch orelse builtin.target.cpu.arch;
    // TODO crc32c impl has a bug on arm64 when on debug mode
    const with_crc32c_arm64 = arch == .aarch64 and optimize != .Debug;

    const build_options = b.addOptions();
    build_options.addOption(
        []const u8,
        "version",
        b.option(
            []const u8,
            "version",
            "the app version",
        ) orelse parseGitRevHead(b.allocator) catch "master",
    );
    const bm: BuildModule = .{
        .b = b,
        // .m = ModuleMap.init(b.allocator),
        .tests = b.step("test", "Run all tests"),
        .target = target,
        .optimize = optimize,
        .optimize_idx = @intFromEnum(optimize),
        .build_options = build_options.createModule(),
        .c_flags = if (!with_crc32c_arm64) c_flags_def else c_flags_arm64,
        .cpp_flags = if (!with_crc32c_arm64) cpp_flags_def else cpp_flags_arm64,
        .test_filters = b.option(
            []const []const u8,
            "test-filter",
            "test-filter",
        ) orelse &.{},
    };

    // ======================================================================
    // deps

    // no zig.zon deps

    // ======================================================================
    // cpp lib

    const lib = b.addStaticLibrary(.{
        .name = "zpp_crc32c",
        .target = target,
        .optimize = optimize,
    });
    const lib_export = "crc32c/crc32c.h";
    const lib_header = b.path("crc32c/include/" ++ lib_export);

    lib.addIncludePath(b.path("crc32c/include"));
    lib.addIncludePath(b.path("crc32c/config-include"));
    lib.linkLibCpp();
    lib.addCSourceFiles(.{
        .root = b.path("crc32c/src"),
        .files = if (!with_crc32c_arm64) cpp_srcs else cpp_srcs_arm64,
        .flags = bm.cpp_flags,
    });
    // lib.addCSourceFiles(.{
    //     .root = b.path("src"),
    //     .files = &.{
    //         "lib.cpp",
    //     },
    //     .flags = c_flags,
    // });

    lib.installHeader(lib_header, lib_export);
    b.default_step.dependOn(&b.addInstallHeaderFile(
        lib_header,
        lib_export,
    ).step);
    b.installArtifact(lib);

    // ======================================================================
    // module

    const mod = b.addModule("zpp_crc32c", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.linkLibrary(lib);
    mod.addImport("zpp_crc32c_clib", b.addTranslateC(.{
        .root_source_file = lib_header,
        .target = target,
        .optimize = optimize,
    }).createModule());

    // ======================================================================
    // tests

    const lib_test = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .filters = bm.test_filters,
    });
    lib_test.root_module.linkLibrary(lib);
    bm.tests.dependOn(&b.addRunArtifact(lib_test).step);

    // const mod_test = addModuleTo(
    //     &bm,
    //     .test_only,
    //     "tests/test.zig",
    //     "",
    // );
    // mod_test.addImport("zpp_crc32c", mod);

    // ======================================================================
    // executables

    addModuleTo(
        &bm,
        .exe_only,
        "crc32c/src/crc32c_capi_unittest.c",
        "",
    ).linkLibrary(lib);

    addModuleTo(
        &bm,
        .exe_only,
        "src/example.c",
        "",
    ).linkLibrary(lib);

    const example = addModuleTo(
        &bm,
        .exe_only,
        "src/example.zig",
        "run",
    );
    example.addImport("zpp_crc32c", mod);
}
