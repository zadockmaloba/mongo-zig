const std = @import("std");

pub const mongoc = @cImport({
    @cInclude("mongoc/mongoc.h");
    @cInclude("bson/bson.h");
});
