const std = @import("std");
const Schema = @import("./types.zig").Schema;
const Limits = @import("./limits.zig");
const array = @import("arrow").array;
const BuilderInner = array.Builder;
const DataType = @import("./types.zig").DataType;
const TableError = @import("./error.zig").TableError;
const logger = std.log.scoped(.database);

fn B(comptime T: type) type {
    return struct {
        builder: BuilderInner(T),
        const Self = @This();
        fn append(self: *anyopaque, value: *anyopaque) std.mem.Allocator.Error!void {
            const _self: *Self = @ptrCast(@alignCast(self));
            const _value: *T = @ptrCast(@alignCast(value));
            try _self.builder.append(_value.*);
        }
        fn init(allocator: std.mem.Allocator) !Self {
            return .{ .builder = try BuilderInner(T).init(allocator) };
        }
        fn to_builder(self: *@This()) Builder {
            return .{ .inner_builder = self, .vtable = .{ .append = append } };
        }
    };
}
const Builder = struct {
    inner_builder: *anyopaque,
    vtable: struct { append: *const fn (*anyopaque, *anyopaque) std.mem.Allocator.Error!void },
    fn append(self: *@This(), value: anytype) !void {
        // FIXME: Don't use const cast
        try self.vtable.append(self.inner_builder, @constCast(&value));
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
        fn fill(self: *@This(), value: anytype) !void {
            const column = self.table.schema.get(self.position);
            return switch (@typeInfo(@TypeOf(value))) {
                .bool => {
                    if (column.data_type != DataType.bool) {
                        logger.info("Value cannot be appended to table {s}. Expected {s} and received bool", .{ self.table.name, @tagName(column.data_type) });
                        return TableError.append;
                    }
                    try self.table.values[self.position].append(value);
                    self.position += 1;
                },
                .@"struct" => |type_info| {
                    inline for (type_info.fields) |field| {
                        if (!std.mem.eql(u8, column.name, field.name)) {
                            logger.info("Value cannot be appended to table {s}. Expected column_name {s} and received {s}", .{ self.table.name, column.name, field.name });
                            return TableError.column_name;
                        }
                        try self.fill(@field(value, field.name));
                        self.position += 1;
                    }
                },
                else => @compileError("not supporting other types"),
            };
        }
    };

    const Self = @This();
    pub fn from_schema(name: []const u8, schema: *const Schema, allocator: std.mem.Allocator) !Table {
        var builders = try std.ArrayList(Builder).initCapacity(allocator, schema.len);
        for (0..schema.len) |index| {
            const val = schema.get(index);
            const hello = blk: {
                switch (val.data_type) {
                    .bool => {
                        var b = try B(bool).init(allocator);
                        break :blk b.to_builder();
                    },
                    .int64 => {
                        var b = try B(i64).init(allocator);
                        break :blk b.to_builder();
                    },
                    .int32 => {
                        var b = try B(i32).init(allocator);
                        break :blk b.to_builder();
                    },
                    .float32 => {
                        var b = try B(f32).init(allocator);
                        break :blk b.to_builder();
                    },
                    .float64 => {
                        var b = try B(f64).init(allocator);
                        break :blk b.to_builder();
                    },
                }
            };
            try builders.append(hello);
        }
        return .{ .name = name, .allocator = allocator, .values = try builders.toOwnedSlice(), .schema = schema };
    }
    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }
    pub fn append(self: *Self, value: anytype) !void {
        var row = Row{ .table = self };
        try row.fill(value);
    }
};
