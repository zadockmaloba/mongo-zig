const std = @import("std");

const utf8_header_files = .{
    "utf8proc.h",
    "utf8proc_data.c",
};

const utf8_src_files = &.{
    "utf8proc.c",
};

const CFLAGS = &.{
    "-std=c23",
};

pub fn addUtf8ToLibrary(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
    _ = lib;
    const utf8_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
    });

    utf8_mod.addCSourceFiles(.{
        .files = utf8_src_files,
        .flags = CFLAGS,
        .root = upstream.path("src/utf8proc-2.8.0/"),
    });

    utf8_mod.addIncludePath(upstream.path("src/utf8proc-2.8.0/"));

    utf8_mod.addCMacro("UTF8PROC_STATIC", "1");

    return utf8_mod;
}
