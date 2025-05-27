const std = @import("std");
const bson_build = @import("build/bson.zig");

const common_config_files = .{
    "common-config.h",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_zig",
        .root_module = lib_mod,
    });

    //==========================================
    const upstream = b.dependency("mongo-c", .{
        .target = target,
        .optimize = optimize,
    });

    const common_conf = b.addConfigHeader(
        .{
            .style = .{ .cmake = upstream.path("src/common/src/" ++ "common-config.h.in") },
            .include_path = "common-config.h",
        },
        .{
            .MONGOC_ENABLE_DEBUG_ASSERTIONS = 0,
        },
    );

    lib.installConfigHeader(common_conf);

    const bson_mod = try bson_build.addBsonToLibrary(b, lib, upstream, target, optimize);
    bson_mod.addConfigHeader(common_conf);
    lib_mod.addImport("bson", bson_mod);

    //==========================================

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
