const std = @import("std");

const mongo = @import("mongo_zig");

pub fn main() !void {
    mongo.mongocInit();
    defer mongo.mongocInit();

    const client = try mongo.MongoClient.init("mongodb://localhost:27017");
    defer client.deinit();
}
