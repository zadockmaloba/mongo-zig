const std = @import("std");

const mongo = @import("mongo_zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    const uri =
        try std.fmt.allocPrintZ(gpa.allocator(), "mongodb://{s}", .{if (args.len > 1) args[1] else "localhost:27017"});
    defer gpa.allocator().free(uri);

    const bson_allocator = mongo.BsonAllocator.init(std.heap.page_allocator);
    mongo.mongocInit();
    defer mongo.mongocDeinit();

    const client = try mongo.MongoClient.init(bson_allocator, uri);
    defer client.deinit();

    const db = try client.getDatabase("test");
    defer db.deinit();

    const ping: mongo.MongoBson = mongo.MongoBson.init(bson_allocator, mongo.BSON_NEW("ping", .{ .bcon_type_int32 = 1 }));
    defer ping.deinit();

    _ = client.sendSimpleCommand("admin", ping) catch |err| {
        std.log.err("Failed to send command: {}", .{err});
        return err;
    };
}

test "Mongo Allocation" {
    const bson_allocator = mongo.BsonAllocator.init(std.testing.allocator);
    defer bson_allocator.deinit();

    mongo.mongocInit();
    defer mongo.mongocDeinit();

    const client = try mongo.MongoClient.init(bson_allocator, "mongodb://localhost:27017");
    defer client.deinit();

    const db = try client.getDatabase("test");
    defer db.deinit();
}

test "Bson new" {
    const allocator = std.testing.allocator;
    const bson_allocator = mongo.BsonAllocator.init(allocator);
    defer bson_allocator.deinit();
    const b = mongo.MongoBson.init(bson_allocator, mongo.bson_new(null, "BCON_MAGIC", @as(c_int, @intCast(0))));
    defer b.deinit();
    //try std.testing.expect(b.ptr != null);
    //try std.testing.expect(b.ptr.* == .{});
}
