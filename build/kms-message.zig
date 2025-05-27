const std = @import("std");

const kms_src_files = &.{
    "hexlify.c",
    "kms_azure_request.c",
    "kms_b64.c",
    "kms_caller_identity_request.c",
    "kms_crypto_apple.c",
    "kms_crypto_libcrypto.c",
    "kms_crypto_none.c",
    "kms_crypto_windows.c",
    "kms_decrypt_request.c",
    "kms_encrypt_request.c",
    "kms_gcp_request.c",
    "kms_kmip_reader_writer.c",
    "kms_kmip_request.c",
    "kms_kmip_response.c",
    "kms_kmip_response_parser.c",
    "kms_kv_list.c",
    "kms_message.c",
    "kms_port.c",
    "kms_request.c",
    "kms_request_opt.c",
    "kms_request_str.c",
    "kms_response.c",
    "kms_response_parser.c",
    "sort.c",
};

const CFLAGS = &.{
    "-std=c23",
};

pub fn addKmsToLibrary(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
    _ = lib;
    const kms_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
    });

    kms_mod.addCSourceFiles(.{
        .files = kms_src_files,
        .flags = CFLAGS,
        .root = upstream.path("src/kms-message/src/"),
    });

    kms_mod.addIncludePath(upstream.path("src/kms-message/src"));

    kms_mod.addCMacro("KMS_MESSAGE_LITTLE_ENDIAN", "1");

    return kms_mod;
}
