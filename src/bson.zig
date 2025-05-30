const std = @import("std");

const bson = @cImport({
    @cInclude("bson/bson.h");
});
