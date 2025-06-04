const std = @import("std");

const mongo = @import("mongo_zig");

pub fn main() !void {
    const bson_allocator = mongo.BsonAllocator.init(std.heap.page_allocator);

    mongo.mongocInit();
    defer mongo.mongocDeinit();
    errdefer mongo.mongocDeinit();

    const client = try mongo.MongoClient.init(bson_allocator, "mongodb://localhost:27017");
    defer client.deinit();

    const db = try client.getDatabase("test");
    defer db.deinit();

    const ping: mongo.MongoBson = mongo.MongoBson.init(bson_allocator, mongo.BSON_NEW("ping", .{ .bcon_type_int32 = 1 }));

    _ = client.sendSimpleCommand("admin", ping) catch |err| {
        std.log.err("Failed to send command: {}", .{err});
        return err;
    };
}
