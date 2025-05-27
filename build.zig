const std = @import("std");

const common_config_files = .{
    "common-config.h",
};

const bson_config_files = .{
    "bson-config.h",
    "bson-version.h",
};

const bson_header_files = &.{
    "bcon.h",
    "bson-clock.h",
    "bson-compat.h",
    "bson-context-private.h",
    "bson-context.h",
    "bson-decimal128.h",
    "bson-endian.h",
    "bson-error-private.h",
    "bson-error.h",
    "bson-iso8601-private.h",
    "bson-iter.h",
    "bson-json-private.h",
    "bson-json.h",
    "bson-keys.h",
    "bson-macros.h",
    "bson-memory.h",
    "bson-oid.h",
    "bson-prelude.h",
    "bson-private.h",
    "bson-reader.h",
    "bson-string.h",
    "bson-timegm-private.h",
    "bson-types.h",
    "bson-utf8.h",
    "bson-value.h",
    "bson-vector-private.h",
    "bson-vector.h",
    "bson-version-functions.h",
    "bson-writer.h",
    "bson.h",
};

const bson_src_files = &.{
    "bcon.c",
    "bson-clock.c",
    "bson-context.c",
    "bson-decimal128.c",
    "bson-error.c",
    "bson-iso8601.c",
    "bson-iter.c",
    "bson-json.c",
    "bson-keys.c",
    "bson-memory.c",
    "bson-oid.c",
    "bson-reader.c",
    "bson-string.c",
    "bson-timegm.c",
    "bson-utf8.c",
    "bson-value.c",
    "bson-vector.c",
    "bson-version-functions.c",
    "bson-writer.c",
    "bson.c",
};

const CFLAGS_STRICT = &.{
    "-std=c23",
    "-fwrapv",
    "-fno-strict-aliasing",
    "-fexcess-precision=standard",

    "-Wno-unused-command-line-argument",
    "-Wno-compound-token-split-by-macro",
    "-Wno-format-truncation",
    "-Wno-cast-function-type-strict",

    //"-Werror",
    "-Wall",
    "-Wmissing-prototypes",
    "-Wpointer-arith",
    "-Wvla",
    "-Wunguarded-availability-new",
    "-Wendif-labels",
    "-Wmissing-format-attribute",
    "-Wformat-security",
};

const CFLAGS = &.{
    "-std=c23",
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

    const bson_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
    });

    bson_mod.addCSourceFiles(.{
        .files = bson_src_files,
        .flags = CFLAGS,
        .root = upstream.path("src/libbson/src/bson"),
    });

    inline for (bson_config_files) |_header| {
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
                //.BSON_OS = if (target.result.os.tag == .windows) 2 else 1,
                .BSON_OS = 1,
                .BSON_HAVE_CLOCK_GETTIME = 1,
                .BSON_HAVE_STRINGS_H = 1,
                .BSON_HAVE_STRNLEN = 1,
                .BSON_HAVE_SNPRINTF = 1,
                .BSON_HAVE_GMTIME_R = 1,
                .BSON_HAVE_TIMESPEC = 1,
                .BSON_HAVE_RAND_R = 1,
                .BSON_HAVE_STRLCPY = 1,
                .BSON_HAVE_ALIGNED_ALLOC = 1,
            },
        );
        lib.installConfigHeader(tmp);
        bson_mod.addConfigHeader(common_conf);
        bson_mod.addConfigHeader(tmp);
    }

    bson_mod.addIncludePath(upstream.path("src/common/src"));
    bson_mod.addIncludePath(upstream.path("src/libbson/src"));

    bson_mod.addCMacro("BSON_COMPILATION", "1");

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
