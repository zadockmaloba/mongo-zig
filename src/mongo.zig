const std = @import("std");

pub const mongoc = @cImport({
    @cInclude("mongoc/mongoc.h");
    @cInclude("bson/bson.h");
});

const bson_namespace = @import("bson.zig");
pub const BSON_NEW = bson_namespace.BSON_NEW;
pub const BsonAllocator = bson_namespace.BsonAllocator;
pub const Bson = bson_namespace.Bson;
pub const BsonError = bson_namespace.BsonError;
pub const MongoBson = bson_namespace.MongoBson;

pub fn mongocInit() void {
    mongoc.mongoc_init();
}

pub fn mongocDeinit() void {
    mongoc.mongoc_cleanup();
}

pub const MongoDatabase = struct {
    db: *mongoc.mongoc_database_t,
    pub fn init(db: *mongoc.mongoc_database_t) !MongoDatabase {
        return MongoDatabase{ .db = db };
    }
    pub fn deinit(self: MongoDatabase) void {
        mongoc.mongoc_database_destroy(self.db);
    }
};

pub const MongoClient = struct {
    client: *mongoc.mongoc_client_t,
    allocator: BsonAllocator,

    pub fn init(allocator: BsonAllocator, uri: [*c]const u8) !MongoClient {
        //_ = allocator; // Use the allocator for BSON memory management
        const client = mongoc.mongoc_client_new(uri);
        return if (client != null) MongoClient{
            .allocator = allocator,
            .client = client.?,
        } else error.ClientCreationFailed;
    }

    pub fn deinit(self: *const MongoClient) void {
        _ = self;
    }

    pub fn getDatabase(self: MongoClient, db_name: [*c]const u8) !MongoDatabase {
        const db = mongoc.mongoc_client_get_database(self.client, db_name);
        if (db == null) {
            return error.DatabaseNotFound;
        }
        return .{
            .db = db.?,
        };
    }

    pub fn sendSimpleCommand(self: MongoClient, db_name: [*c]const u8, command: MongoBson) !mongoc.bson_t {
        var reply = mongoc.bson_t{};
        const result = mongoc.mongoc_client_command_simple(
            self.client,
            db_name,
            @ptrCast(command.ptr),
            null,
            &reply,
            null,
        );
        if (!result) {
            return error.CommandFailed;
        }
        return reply;
    }
};
