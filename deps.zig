const std = @import("std");
const builtin = @import("builtin");
const Pkg = std.build.Pkg;
const string = []const u8;

pub const cache = ".zigmod/deps";

pub fn addAllTo(
    exe: *std.build.LibExeObjStep,
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
) *std.build.LibExeObjStep {
    @setEvalBranchQuota(1_000_000);

    exe.setTarget(target);
    exe.setBuildMode(mode);

    // lazy
    if (c_libs[0] == null) resolveCLibs(b, target, mode);
    for (c_libs) |c_lib| exe.linkLibrary(c_lib.?);

    for (packages) |pkg| {
        exe.addPackage(pkg.pkg.?);
    }
    inline for (std.meta.declarations(package_data)) |decl| {
        const pkg = @as(Package, @field(package_data, decl.name));
        inline for (pkg.system_libs) |item| {
            exe.linkSystemLibrary(item);
        }
        inline for (pkg.c_include_dirs) |item| {
            exe.addIncludeDir(@field(dirs, decl.name) ++ "/" ++ item);
        }
        inline for (pkg.c_source_files) |item| {
            exe.addCSourceFile(@field(dirs, decl.name) ++ "/" ++ item, pkg.c_source_flags);
        }
    }

    exe.linkLibC();

    return exe;
}

pub const CLib = struct {
    name: string,
    idx: usize,
    pub fn getStep(self: *CLib) ?*std.build.LibExeObjStep {
        return c_libs[self.idx];
    }
};

pub const Package = struct {
    directory: string,
    pkg: ?Pkg = null,
    c_include_dirs: []const string = &.{},
    c_libs: []const CLib = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
    vcpkg: bool = false,
};

pub const dirs = struct {
    pub const _root = "";
    pub const _ju1a3i1krntg = ".";
};

const zero_deps_map = std.ComptimeStringMap(string, .{ .{ "", "" } });

pub const dep_dirs = struct {
    pub const _root = std.ComptimeStringMap(string, .{
        .{ "zpp-crc32c", dirs._ju1a3i1krntg },
    });
    pub const _ju1a3i1krntg = zero_deps_map;
};

pub const package_data = struct {
    pub const _ju1a3i1krntg = Package{
        .directory = dirs._ju1a3i1krntg,
        .pkg = Pkg{ .name = "zpp-crc32c", .path = .{ .path = dirs._ju1a3i1krntg ++ "/src/lib.zig" }, .dependencies = null },
        .c_include_dirs = &.{ "crc32c/include" },
        .c_libs = &.{
            .{ .name = "crc32c", .idx = 0 },
        },
    };
    pub const _root = Package{
        .directory = dirs._root,
    };
};

pub const packages = &[_]Package{
    package_data._ju1a3i1krntg,
};

pub const pkgs = struct {
    pub const zpp_crc32c = package_data._ju1a3i1krntg;
};


// lazy
var c_libs = std.mem.zeroes([1]?*std.build.LibExeObjStep);

fn resolveCLibs(
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
) void {
    c_libs[0] = @import("crc32c_lib.zig").configure(
        dirs._ju1a3i1krntg,
        dep_dirs._ju1a3i1krntg,
        dep_dirs._root,
        b.allocator,
        b.addStaticLibrary("crc32c", null),
        target, mode,
    );
}

