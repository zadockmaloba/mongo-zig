const std = @import("std");

const bson = @cImport({
    @cInclude("bson/bson.h");
});

// Re-export the BSON types and functions
pub const Bson = bson.bson_t;
pub const BsonError = bson.bson_error_t;

/// BSON memory management functionality
pub const BsonAllocator = struct {
    /// Global allocator used by BSON if none is provided
    allocator: std.mem.Allocator,

    var default_allocator: std.mem.Allocator = undefined;
    var allocations: std.AutoArrayHashMap(usize, usize) = undefined;
    const _align = 8;

    pub fn init(allocator: std.mem.Allocator) BsonAllocator {
        //REF: https://mongoc.org/libbson/current/bson_mem_set_vtable.html
        const vtable = bson.bson_mem_vtable_t{
            .malloc = malloc,
            .calloc = calloc,
            .realloc = realloc,
            .free = free,
            .aligned_alloc = null, //alignedAlloc,
            .padding = undefined,
        };
        bson.bson_mem_set_vtable(&vtable);
        default_allocator = allocator;
        allocations = std.AutoArrayHashMap(usize, usize).init(allocator);

        return BsonAllocator{
            .allocator = allocator,
        };
    }
    pub fn deinit(self: BsonAllocator) void {
        // No explicit deinitialization needed for BSON
        // The allocator will be cleaned up by the caller
        _ = self;
        allocations.deinit();
    }

    // Callback implementations that bridge Zig's allocator to BSON's vtable

    fn malloc(size: usize) callconv(.C) ?*anyopaque {
        const tmp = default_allocator.alignedAlloc(u8, 8, size) catch |err| {
            std.log.err("BSON malloc failed: {}", .{err});
            return null;
        };
        std.debug.assert(@intFromPtr(tmp.ptr) % _align == 0); // Ensure alignment
        allocations.put(@intFromPtr(tmp.ptr), size) catch |err| {
            std.log.err("BSON malloc tracking failed: {}", .{err});
            return null;
        };
        std.debug.print("[MALLOC]: Updated allocations: {any}, ptr: {x}\n", .{
            allocations.count(),
            @intFromPtr(tmp.ptr),
        });
        return tmp.ptr;
    }

    fn calloc(n_members: usize, size: usize) callconv(.C) ?*anyopaque {
        const total = n_members * size;
        const tmp = default_allocator.alignedAlloc(u8, 8, size) catch |err| {
            std.log.err("BSON calloc failed: {}", .{err});
            return null;
        };
        std.debug.assert(@intFromPtr(tmp.ptr) % _align == 0); // Ensure alignment
        const ptr = tmp.ptr;
        @memset(@as([*]u8, @alignCast(ptr))[0..total], 0);
        allocations.put(@intFromPtr(ptr), total) catch |err| {
            std.log.err("BSON calloc tracking failed: {}", .{err});
            return null;
        };
        std.debug.print("[CALLOC]: Updated allocations: {any}, ptr: {x}\n", .{
            allocations.count(),
            @intFromPtr(ptr),
        });
        return ptr;
    }

    fn realloc(ptr: ?*anyopaque, new_size: usize) callconv(.C) ?*anyopaque {
        if (ptr == null) return malloc(new_size);
        const val = allocations.get(@intFromPtr(ptr.?));
        if (val) |old_size| {
            _ = allocations.orderedRemove(@intFromPtr(ptr.?));
            const ret = default_allocator.realloc(@as([*]u8, @ptrCast(ptr.?))[0..old_size], new_size) catch |err| {
                std.log.err("Failed to reallocate memory: {}\n", .{err});
                return null;
            };
            allocations.put(@intFromPtr(ptr), new_size) catch |err| {
                std.log.err("BSON realloc tracking failed: {}", .{err});
                //default_allocator.free(ptr.?);
                return null;
            };
            std.debug.print("[REALLOC]: Updated allocations: {any}, old_ptr: {x}, new_ptr: {x}\n", .{
                allocations.count(),
                @intFromPtr(ptr.?),
                @intFromPtr(ret.ptr),
            });
            return ret.ptr;
        } else {
            // If we can't find the allocation, we can't free it safely
            std.debug.print("Warning: Attempted to free untracked pointer: {}\n", .{@intFromPtr(ptr.?)});
        }
        std.debug.print("[REALLOC]: Updated allocations: {any}\n", .{allocations.count()});
        return ptr.?;
    }

    fn free(ptr: ?*anyopaque) callconv(.C) void {
        if (ptr) |p| {
            const val = allocations.get(@intFromPtr(p));
            if (val) |size| {
                _ = allocations.orderedRemove(@intFromPtr(p));
                default_allocator.free(@as([*]u8, @ptrCast(p))[0..size]);
            } else {
                // If we can't find the allocation, we can't free it safely
                std.debug.print("Warning: Attempted to free untracked pointer: {}\n", .{@intFromPtr(p)});
            }
        }
        std.debug.print("[MEMFREE]: Updated allocations: {any}\n", .{allocations.count()});
    }

    fn alignedAlloc(alignment: usize, size: usize) callconv(.C) ?*anyopaque {
        return default_allocator.allocAdvancedWithRetAddr(u8, alignment, size, @returnAddress()) catch return null;
    }
};

pub const bcon_types = union(enum) {
    bcon_type_utf8: [*c]const u8,
    bcon_type_double: f64,
    bcon_type_document: bool,
    bcon_type_array: bool,
    bcon_type_bin: bool,
    bcon_type_undefined: bool,
    bcon_type_oid: bool,
    bcon_type_bool: bool,
    bcon_type_date_time: bool,
    bcon_type_null: bool,
    bcon_type_regex: bool,
    bcon_type_dbpointer: bool,
    bcon_type_code: bool,
    bcon_type_symbol: bool,
    bcon_type_codewscope: bool,
    bcon_type_int32: i32,
    bcon_type_timestamp: bool,
    bcon_type_int64: bool,
    bcon_type_decimal128: bool,
    bcon_type_maxkey: bool,
    bcon_type_minkey: bool,
    bcon_type_bcon: bool,
    bcon_type_array_start: bool,
    bcon_type_array_end: bool,
    bcon_type_doc_start: bool,
    bcon_type_doc_end: bool,
    bcon_type_end: bool,
    bcon_type_raw: bool,
    bcon_type_skip: bool,
    bcon_type_iter: bool,
    bcon_type_error: bool,
};

pub extern "c" fn bson_new(unused: ?*anyopaque, ...) *Bson;

pub const BCON_MAGIC = "BCON_MAGIC";
pub const BCONE_MAGIC = "BCONE_MAGIC";

pub fn BSON_NEW(key: [*c]const u8, _type: bcon_types) ?*Bson {
    _ = key;
    switch (_type) {
        .bcon_type_int32 => |val| {
            return bson_new(
                null,
                BCON_MAGIC,
                @as(c_int, @intCast(@intFromEnum(bcon_types.bcon_type_int32))),
                val,
            );
        },
        else => {},
    }
    return null;
}

pub const MongoBson = struct {
    ptr: *Bson,
    allocator: BsonAllocator,

    pub fn init(allocator: BsonAllocator, _bson: ?*Bson) MongoBson {
        return .{
            .allocator = allocator,
            .ptr = _bson.?,
        };
    }

    pub fn deinit(self: MongoBson) void {
        bson.bson_destroy(self.ptr);
    }
};
