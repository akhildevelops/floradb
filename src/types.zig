const std = @import("std");
pub const DataType = enum { bool, int64, int32, float32, float64 };
pub const Column = struct { name: []const u8, data_type: DataType };
pub const Schema = std.MultiArrayList(Column);
