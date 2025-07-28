const std = @import("std");
const flora64 = @import("flora64");
const utils = @import("./utils.zig");
const Limits = flora64.Limits;
const DataTypes = flora64.DataTypes;
const Database = flora64.Database.Database;
const Table = flora64.Database.Table;
test {
    var schema = std.StringHashMap(DataTypes).init(std.testing.allocator);
    defer schema.deinit();
    try schema.put("age", DataTypes.int32);
    const db = Database{ .allocator = std.testing.allocator, .name = "First" };
    var table = try db.from_schema("First_tb", &schema);
    defer table.deinit();
    const values = [_]u8{ 1, 2, 3 };
    var val_ref: [3]*const u8 = undefined;
    val_ref[0] = &values[0];
    val_ref[1] = &values[1];
    val_ref[2] = &values[2];
    try table.insert(&val_ref);
}
