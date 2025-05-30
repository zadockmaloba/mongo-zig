const std = @import("std");

pub export const mongoc = @cImport({
    @cInclude("mongoc/mongoc.h");
    @cInclude("bson/bson.h");
});
