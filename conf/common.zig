const std = @import("std");

const comm_src_files = &.{
    "common-atomic.c",
    "common-b64.c",
    "common-json.c",
    "common-md5.c",
    "common-oid.c",
    "common-string.c",
    "common-thread.c",
};

const CFLAGS = &.{
    "-std=c23",
    "-pthread",
};

pub fn addCommonToLibrary(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
    _ = lib;
    const comm_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
    });

    comm_mod.addCSourceFiles(.{
        .files = comm_src_files,
        .flags = CFLAGS,
        .root = upstream.path("src/common/src/"),
    });

    comm_mod.addIncludePath(upstream.path("src/common/src"));
    comm_mod.addIncludePath(upstream.path("src/libbson/src"));

    comm_mod.addCMacro("BSON_COMPILATION", "1");

    if (target.result.os.tag == .linux) {
        comm_mod.addCMacro("_POSIX_C_SOURCE", "200809L");
        comm_mod.addCMacro("_GNU_SOURCE", "1");
        //comm_mod.linkSystemLibrary("pthread", .{});
    }

    return comm_mod;
}
