const std = @import("std");
pub const DataType = enum { bool, int64, int32, float32, float64 };
pub const Schema = std.StringHashMap(DataType);
