const std = @import("std");

const mongo = @import("mongo_zig");

pub fn main() !void {
    const bson_allocator = mongo.BsonAllocator.init(std.heap.page_allocator);

    mongo.mongocInit();
    defer mongo.mongocDeinit();
    errdefer mongo.mongocDeinit();

    const client = try mongo.MongoClient.init(bson_allocator, "mongodb://localhost:27017");
    defer client.deinit();
}
