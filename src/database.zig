const std = @import("std");
const Schema = @import("./types.zig").Schema;
const Limits = @import("./limits.zig");
const array = @import("arrow").array;
const BuilderInner = array.Builder;
const DataType = @import("./types.zig").DataType;
const TableError = @import("./error.zig").TableError;
pub const std_options: std.Options = .{ .log_level = std.log.Level.debug };
const logger = std.log.scoped(.database);
fn B(comptime T: type) type {
    return struct {
        builder: BuilderInner(T),
        const Self = @This();
        fn append(self: *anyopaque, value: *const anyopaque) std.mem.Allocator.Error!void {
            const _self: *Self = @ptrCast(@alignCast(self));
            const _value: *const T = @ptrCast(@alignCast(value));
            try _self.builder.append(_value.*);
        }
        fn init(allocator: std.mem.Allocator) !Self {
            return .{ .builder = try BuilderInner(T).init(allocator) };
        }
        fn to_builder(self: *@This()) Builder {
            return .{ .inner_builder = self, .vtable = .{ .append = append, .deinit = deinit, .self_destroy = self_destroy } };
        }
        fn deinit(self: *anyopaque, _: std.mem.Allocator) void {
            const myself: *@This() = @ptrCast(@alignCast(self));
            myself.builder.deinit();
        }
        fn self_destroy(self: *anyopaque, allocator: std.mem.Allocator) void {
            const myself: *@This() = @ptrCast(@alignCast(self));
            allocator.destroy(myself);
        }
    };
}
const Builder = struct {
    inner_builder: *anyopaque,
    vtable: struct { append: *const fn (*anyopaque, *const anyopaque) std.mem.Allocator.Error!void, deinit: *const fn (*anyopaque, allocator: std.mem.Allocator) void, self_destroy: *const fn (*anyopaque, allocator: std.mem.Allocator) void },
    fn append(self: *@This(), value: anytype) !void {
        try self.vtable.append(self.inner_builder, &value);
    }
    fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.vtable.deinit(self.inner_builder, allocator);
    }
    fn inner_builder_destory(self: *@This(), allocator: std.mem.Allocator) void {
        self.vtable.self_destroy(self.inner_builder, allocator);
    }
};

pub const Table = struct {
    name: []const u8,
    allocator: std.mem.Allocator,
    values: []Builder,
    schema: *const Schema,

    const Row = struct {
        position: usize = 0,
        table: *Table,
        n_cols: usize,
        schema: *const Schema,
        schema_iterator: std.hash_map.StringHashMap(DataType).Iterator,
        fn fill(self: *@This(), value: anytype, o_data_type: ?DataType) !void {
            switch (@typeInfo(@TypeOf(value))) {
                .bool => {
                    const d = blk: {
                        if (o_data_type) |datat_type| {
                            break :blk datat_type;
                        } else {
                            const entry = self.schema_iterator.next().?;
                            break :blk entry.value_ptr.*;
                        }
                    };
                    if (d != DataType.bool) {
                        logger.info("Value cannot be appended to table {s}. Expected {s} and received bool", .{ self.table.name, @tagName(d) });
                        return TableError.append;
                    }
                    try self.table.values[self.position].append(value);
                    self.position += 1;
                },
                .@"struct" => |type_info| {
                    if (type_info.fields.len > self.n_cols) {
                        logger.err("Received input row has more number of fields: {d}, compared to provided schema: {d}.", .{ type_info.fields.len, self.n_cols });
                        return TableError.low_input_size;
                    }
                    inline for (type_info.fields) |field| {
                        if (self.schema.get(field.name)) |dt| {
                            try self.fill(@field(value, field.name), dt);
                        } else {
                            logger.err("Column {s} cannot be found in Schema. {}", .{ field.name, self.schema });
                            return TableError.column_name;
                        }
                    }
                },
                else => @compileError("not supporting other types"),
            }
        }
    };

    const Self = @This();
    pub fn from_schema(name: []const u8, schema: *const Schema, allocator: std.mem.Allocator) !Table {
        var builders = try std.ArrayList(Builder).initCapacity(allocator, schema.count());
        var s_it = schema.iterator();
        while (s_it.next()) |entry| {
            const val = entry.value_ptr.*;
            const hello = blk: {
                switch (val) {
                    .bool => {
                        const b = try allocator.create(B(bool));
                        b.* = try B(bool).init(allocator);
                        break :blk b.to_builder();
                    },
                    .int64 => {
                        const b = try allocator.create(B(i64));
                        b.* = try B(i64).init(allocator);
                        break :blk b.to_builder();
                    },
                    .int32 => {
                        const b = try allocator.create(B(i32));
                        b.* = try B(i32).init(allocator);
                        break :blk b.to_builder();
                    },
                    .float32 => {
                        const b = try allocator.create(B(f32));
                        b.* = try B(f32).init(allocator);
                        break :blk b.to_builder();
                    },
                    .float64 => {
                        const b = try allocator.create(B(f64));
                        b.* = try B(f64).init(allocator);
                        break :blk b.to_builder();
                    },
                }
            };
            try builders.append(hello);
        }
        return .{ .name = name, .allocator = allocator, .values = try builders.toOwnedSlice(), .schema = schema };
    }
    pub fn deinit(self: *Self) void {
        for (self.values) |*builder| {
            builder.deinit(self.allocator);
            builder.inner_builder_destory(self.allocator);
        }
        self.allocator.free(self.values);
    }
    pub fn append(self: *Self, value: anytype) !void {
        var row = Row{ .table = self, .schema = self.schema, .schema_iterator = self.schema.iterator(), .n_cols = self.schema.count() };
        try row.fill(value, null);
    }
};
