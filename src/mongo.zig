const std = @import("std");

pub const mongoc = @cImport({
    @cInclude("mongoc/mongoc.h");
    @cInclude("bson/bson.h");
});

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
    pub fn deinit(self: *MongoDatabase) void {
        mongoc.mongoc_database_destroy(self.db);
    }
};

pub const MongoClient = struct {
    client: *mongoc.mongoc_client_t,

    pub fn init(uri: [*c]const u8) !MongoClient {
        const client = mongoc.mongoc_client_new(uri);
        return if (client != null) MongoClient{ .client = client.? } else error.ClientCreationFailed;
    }

    pub fn deinit(self: *const MongoClient) void {
        _ = self;
    }

    pub fn getDatabase(self: *MongoClient, db_name: []const u8) !MongoDatabase {
        const db = mongoc.mongoc_client_get_database(self.client, db_name);
        if (db == null) {
            return error.DatabaseNotFound;
        }
        return .{
            .db = db,
        };
    }
};
