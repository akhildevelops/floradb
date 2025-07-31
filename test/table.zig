const std = @import("std");
const flora64 = @import("flora64");
const utils = @import("./utils.zig");
const Limits = flora64.Limits;
const DataType = flora64.DataType;
const Table = flora64.Database.Table;
const Schema = flora64.Schema;
test {
    const allocator = std.testing.allocator;
    var schema = Schema.init(allocator);
    defer schema.deinit();
    try schema.put("weight", DataType.bool);
    try schema.put("age", DataType.bool);

    var table = try Table.from_schema("asdf", &schema, allocator);
    defer table.deinit();
    try table.append(.{ .weight = true, .age = false });
}
