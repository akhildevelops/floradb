const std = @import("std");
const flora64 = @import("flora64");
const utils = @import("./utils.zig");
const Limits = flora64.Limits;
const DataType = flora64.DataType;
const Table = flora64.Database.Table;
const Schema = flora64.Schema;
const Column = flora64.Column;
test {
    const allocator = std.testing.allocator;
    var schema = Schema{};
    defer schema.deinit(allocator);
    const col1 = Column{ .name = "weight", .data_type = DataType.bool };
    const col2 = Column{ .name = "age", .data_type = DataType.bool };

    try schema.append(allocator, col1);
    try schema.append(allocator, col2);

    var table = try Table.from_schema("asdf", &schema, allocator);
    try table.append(.{ .weight = true, .age = false });
    // const db = Database{ .allocator = std.testing.allocator, .name = "First" };

    // try table.append();
}
