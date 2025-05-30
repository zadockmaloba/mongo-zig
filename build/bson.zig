const std = @import("std");

pub const bson_config_files = .{
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

const jsonsl_header_files = &.{"jsonsl.h"};

const jsonsl_src_files = &.{"jsonsl.c"};

const CFLAGS = &.{
    "-std=c23",
    "-pthread"
};

pub fn addJsonslToLibrary(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
    _ = lib;
    const jsonsl_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
    });

    jsonsl_mod.addCSourceFiles(.{
        .files = jsonsl_src_files,
        .flags = CFLAGS,
        .root = upstream.path("src/libbson/src/jsonsl"),
    });

    jsonsl_mod.addIncludePath(upstream.path("src/common/src"));
    jsonsl_mod.addIncludePath(upstream.path("src/libbson/src"));

    jsonsl_mod.addCMacro("BSON_COMPILATION", "1");

    return jsonsl_mod;
}

pub fn addBsonToLibrary(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
    _ = lib;
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

    bson_mod.addIncludePath(upstream.path("src/common/src"));
    bson_mod.addIncludePath(upstream.path("src/libbson/src"));
 
    bson_mod.addCMacro("BSON_COMPILATION", "1");

    if (target.result.os.tag == .linux) {
        bson_mod.addCMacro("_POSIX_C_SOURCE", "200809L");
        bson_mod.addCMacro("_GNU_SOURCE", "1");
        //bson_mod.linkSystemLibrary("pthread", .{});
    }
    return bson_mod;
}
