const std = @import("std");
const Schema = @import("./types.zig").Schema;
const Limits = @import("./limits.zig");
pub const Database = struct {
    name: []const u8,
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn deinit(_: *Self) void {}

    pub fn from_schema(self: Self, name: []const u8, schema: *const Schema) !Table {
        return .{ .name = name, .schema = schema, .database = &self, .allocator = self.allocator, .values = try std.ArrayList(*const anyopaque).initCapacity(self.allocator, Limits.IN_MEM_MAX_COUNT) };
    }
};

pub const Table = struct {
    name: []const u8,
    allocator: std.mem.Allocator,
    values: std.ArrayList(*const anyopaque),
    schema: *const Schema,
    database: *const Database,

    const Self = @This();
    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }
    pub fn insert(self: *Self, values: []*const anyopaque) std.mem.Allocator.Error!void {
        try self.values.appendSlice(values);
    }
};
