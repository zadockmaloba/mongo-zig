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
    var allocations: std.AutoArrayHashMap([*]u8, usize) = undefined;

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
        allocations = std.AutoArrayHashMap([*]u8, usize).init(allocator);

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
        const tmp = default_allocator.allocAdvancedWithRetAddr(u8, 1, size, @returnAddress()) catch |err| {
            std.log.err("BSON malloc failed: {}", .{err});
            return null;
        };
        allocations.put(tmp.ptr, size) catch |err| {
            std.log.err("BSON malloc tracking failed: {}", .{err});
            default_allocator.free(tmp);
            return null;
        };
        return tmp.ptr;
    }

    fn calloc(n_members: usize, size: usize) callconv(.C) ?*anyopaque {
        const total = n_members * size;
        const tmp = default_allocator.allocAdvancedWithRetAddr(u8, 1, size, @returnAddress()) catch |err| {
            std.log.err("BSON calloc failed: {}", .{err});
            return null;
        };

        const ptr = tmp.ptr;
        @memset(@as([*]u8, @ptrCast(ptr))[0..total], 0);
        allocations.put(ptr, size) catch |err| {
            std.log.err("BSON calloc tracking failed: {}", .{err});
            default_allocator.free(tmp);
            return null;
        };
        return ptr;
    }

    fn realloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
        if (ptr == null) return malloc(size);
        const tmp = default_allocator.resize(@as([*]u8, @ptrCast(ptr.?))[0..size], size);
        if (!tmp) return null;
        allocations.put(@as([*]u8, @ptrCast(ptr.?)), size) catch |err| {
            std.log.err("BSON realloc tracking failed: {}", .{err});
            return null;
        };
        return ptr.?;
    }

    fn free(ptr: ?*anyopaque) callconv(.C) void {
        if (ptr) |p| {
            const val = allocations.get(@as([*]u8, @ptrCast(p)));
            if (val) |size| {
                _ = allocations.orderedRemove(@as([*]u8, @ptrCast(p)));
                default_allocator.free(@as([*]u8, @ptrCast(p))[0..size]);
            } else {
                // If we can't find the allocation, we can't free it safely
                std.debug.print("Warning: Attempted to free untracked pointer: {}\n", .{@intFromPtr(p)});
            }
        }
    }

    fn alignedAlloc(alignment: usize, size: usize) callconv(.C) ?*anyopaque {
        return default_allocator.allocAdvancedWithRetAddr(u8, alignment, size, @returnAddress()) catch return null;
    }
};
