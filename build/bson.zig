const std = @import("std");

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

const CFLAGS = &.{
    "-std=c23",
};

pub fn addBsonToLibrary(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
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
        bson_mod.addConfigHeader(tmp);
    }

    bson_mod.addIncludePath(upstream.path("src/common/src"));
    bson_mod.addIncludePath(upstream.path("src/libbson/src"));

    bson_mod.addCMacro("BSON_COMPILATION", "1");

    return bson_mod;
}
