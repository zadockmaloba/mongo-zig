const std = @import("std");
const bson_build = @import("src/conf/bson.zig");
const mongo_build = @import("src/conf/mongo.zig");
const common_build = @import("src/conf/common.zig");
const kms_build = @import("src/conf/kms-message.zig");
const utf8_build = @import("src/conf/utf8proc.zig");

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
    const comm_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_common",
        .root_module = comm_mod,
    });

    const kms_mod = try kms_build.addKmsToLibrary(b, lib, upstream, target, optimize);
    kms_mod.addConfigHeader(common_conf);
    const kms_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_kms",
        .root_module = kms_mod,
    });

    const utf8_mod = try utf8_build.addUtf8ToLibrary(b, lib, upstream, target, optimize);
    utf8_mod.addConfigHeader(common_conf);
    const utf8_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_utf8",
        .root_module = utf8_mod,
    });

    const jsonsl_mod = try bson_build.addJsonslToLibrary(b, lib, upstream, target, optimize);
    jsonsl_mod.addConfigHeader(common_conf);
    const jsonsl_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_jsonsl",
        .root_module = jsonsl_mod,
    });
    jsonsl_mod.linkLibrary(comm_lib);
    jsonsl_mod.linkLibrary(kms_lib);
    jsonsl_mod.linkLibrary(utf8_lib);

    const bson_mod = try bson_build.addBsonToLibrary(b, lib, upstream, target, optimize);
    bson_mod.addConfigHeader(common_conf);
    const bson_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_bson",
        .root_module = bson_mod,
    });
    bson_mod.linkLibrary(comm_lib);
    bson_mod.linkLibrary(kms_lib);
    bson_mod.linkLibrary(utf8_lib);
    bson_mod.linkLibrary(jsonsl_lib);

    const mongo_mod = try mongo_build.addMongoToLibrary(b, lib, upstream, target, optimize);
    mongo_mod.addConfigHeader(common_conf);
    const mongo_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mongo_mongoc",
        .root_module = mongo_mod,
    });
    mongo_mod.linkLibrary(comm_lib);
    mongo_mod.linkLibrary(kms_lib);
    mongo_mod.linkLibrary(utf8_lib);
    mongo_mod.linkLibrary(jsonsl_lib);
    mongo_mod.linkLibrary(bson_lib);
    mongo_mod.linkLibrary(zlib_dep.artifact("z"));
    mongo_mod.link_libc = true;

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("xcode_frameworks", .{})) |dep| {
            mongo_mod.addSystemFrameworkPath(dep.path("Frameworks"));
            mongo_mod.addSystemIncludePath(dep.path("include"));
            mongo_mod.addLibraryPath(dep.path("lib"));
        }

        mongo_mod.linkFramework("Foundation", .{ .needed = true });
        mongo_mod.linkFramework("Security", .{ .needed = true });
    }

    if (b.lazyDependency("libressl", .{ .target = target, .optimize = optimize })) |libressl_dep| {
        const libressl = libressl_dep.artifact("ssl");
        mongo_mod.linkLibrary(libressl);
    }

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
                .BSON_OS = 1, //Force POSIX for now
                .BSON_HAVE_CLOCK_GETTIME = 1,
                .BSON_HAVE_STRINGS_H = 1,
                .BSON_HAVE_STRNLEN = 1,
                .BSON_HAVE_SNPRINTF = 0,
                .BSON_HAVE_GMTIME_R = 1,
                .BSON_HAVE_TIMESPEC = 1,
                .BSON_HAVE_RAND_R = 1,
                .BSON_HAVE_STRLCPY = 1,
                .BSON_HAVE_ALIGNED_ALLOC = 1,
            },
        );
        lib.installConfigHeader(tmp);

        kms_mod.addConfigHeader(tmp);
        comm_mod.addConfigHeader(tmp);
        bson_mod.addConfigHeader(tmp);
        jsonsl_mod.addConfigHeader(tmp);
        mongo_mod.addConfigHeader(tmp);
    }

    //==========================================

    lib_mod.linkLibrary(comm_lib);
    lib_mod.linkLibrary(kms_lib);
    lib_mod.linkLibrary(utf8_lib);
    lib_mod.linkLibrary(bson_lib);
    lib_mod.linkLibrary(jsonsl_lib);
    lib_mod.linkLibrary(mongo_lib);

    //==========================================

    b.installArtifact(lib);
    b.installArtifact(comm_lib);
    b.installArtifact(kms_lib);
    b.installArtifact(utf8_lib);
    b.installArtifact(bson_lib);
    b.installArtifact(jsonsl_lib);
    b.installArtifact(mongo_lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
