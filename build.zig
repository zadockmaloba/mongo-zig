const std = @import("std");
const bson_build = @import("build/bson.zig");
const common_build = @import("build/common.zig");
const kms_build = @import("build/kms-message.zig");
const utf8_build = @import("build/utf8proc.zig");

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

    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibrary(zlib_dep.artifact("z"));

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

    const comm_mod = try common_build.addCommonToLibrary(b, lib, upstream, target, optimize);
    comm_mod.addConfigHeader(common_conf);

    const kms_mod = try kms_build.addKmsToLibrary(b, lib, upstream, target, optimize);
    kms_mod.addConfigHeader(common_conf);

    const utf8_mod = try utf8_build.addUtf8ToLibrary(b, lib, upstream, target, optimize);
    utf8_mod.addConfigHeader(common_conf);

    const bson_mod = try bson_build.addBsonToLibrary(b, lib, upstream, target, optimize);
    bson_mod.addConfigHeader(common_conf);

    const jsonsl_mod = try bson_build.addJsonslToLibrary(b, lib, upstream, target, optimize);
    jsonsl_mod.addConfigHeader(common_conf);

    lib_mod.addImport("mongo_common", comm_mod);
    lib_mod.addImport("mongo_utf8", utf8_mod);
    lib_mod.addImport("mongo_kms", kms_mod);
    lib_mod.addImport("mongo_bson", bson_mod);
    lib_mod.addImport("mongo_jsonsl", jsonsl_mod);

    inline for (bson_build.bson_config_files) |_header| {
        const tmp = b.addConfigHeader(
            .{
                .style = .{ .cmake = upstream.path("src/libbson/src/bson/" ++ _header ++ ".in") },
                .include_path = "bson/" ++ _header,
            },
            .{
                .libbson_VERSION_MAJOR = 2,
                .libbson_VERSION_MINOR = 0,
                .libbson_VERSION_PATCH = 1,
                .libbson_VERSION_FULL = .@"2.0.1",
                .libbson_VERSION_PRERELEASE = null,
                .BSON_BYTE_ORDER = 1234,
                .BSON_HAVE_STDBOOL_H = 1,
                .BSON_OS = 1,
                .BSON_HAVE_CLOCK_GETTIME = 1,
                .BSON_HAVE_STRINGS_H = 1,
                .BSON_HAVE_STRNLEN = 0, //Fails in Linux systems if set to true
                .BSON_HAVE_SNPRINTF = 0,
                .BSON_HAVE_GMTIME_R = 1,
                .BSON_HAVE_TIMESPEC = 1,
                .BSON_HAVE_RAND_R = 1,
                .BSON_HAVE_STRLCPY = 0, //Fails in Linux systems if set to true
                .BSON_HAVE_ALIGNED_ALLOC = 1,
            },
        );
        lib.installConfigHeader(tmp);

        kms_mod.addConfigHeader(tmp);
        comm_mod.addConfigHeader(tmp);
        bson_mod.addConfigHeader(tmp);
        jsonsl_mod.addConfigHeader(tmp);
    }

    //==========================================

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
