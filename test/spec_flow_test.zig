const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Flow Collections
// Tests flow sequences [a, b, c] and flow mappings {a: 1, b: 2}

test "spec: flow sequence - simple" {
    const Data = struct {
        colors: [][]const u8,
    };

    const yaml = "colors: [red, green, blue]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.colors.len);
    try std.testing.expectEqualStrings("red", data.colors[0]);
    try std.testing.expectEqualStrings("green", data.colors[1]);
    try std.testing.expectEqualStrings("blue", data.colors[2]);
}

test "spec: flow sequence - numbers" {
    const Data = struct {
        coordinates: []i64,
    };

    const yaml = "coordinates: [10, 20, 30, 40]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 4), data.coordinates.len);
    try std.testing.expectEqual(@as(i64, 10), data.coordinates[0]);
    try std.testing.expectEqual(@as(i64, 40), data.coordinates[3]);
}

test "spec: flow sequence - nested" {
    const Data = struct {
        matrix: [][]i64,
    };

    const yaml = "matrix: [[1, 2], [3, 4], [5, 6]]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.matrix.len);
    try std.testing.expectEqual(@as(i64, 1), data.matrix[0][0]);
    try std.testing.expectEqual(@as(i64, 4), data.matrix[1][1]);
    try std.testing.expectEqual(@as(i64, 6), data.matrix[2][1]);
}

test "spec: flow sequence - multiline" {
    const Data = struct {
        items: [][]const u8,
    };

    const yaml =
        \\items: [
        \\  first,
        \\  second,
        \\  third
        \\]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.items.len);
    try std.testing.expectEqualStrings("first", data.items[0]);
    try std.testing.expectEqualStrings("second", data.items[1]);
    try std.testing.expectEqualStrings("third", data.items[2]);
}

test "spec: flow sequence - empty" {
    const Data = struct {
        empty: [][]const u8,
    };

    const yaml = "empty: []\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 0), data.empty.len);
}

test "spec: flow mapping - simple" {
    const Data = struct {
        config: struct {
            host: []const u8,
            port: i64,
        },
    };

    const yaml = "config: {host: localhost, port: 8080}\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("localhost", data.config.host);
    try std.testing.expectEqual(@as(i64, 8080), data.config.port);
}

test "spec: flow mapping - multiline" {
    const Data = struct {
        server: struct {
            host: []const u8,
            port: i64,
            ssl: bool,
        },
    };

    const yaml =
        \\server: {
        \\  host: example.com,
        \\  port: 443,
        \\  ssl: true
        \\}
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("example.com", data.server.host);
    try std.testing.expectEqual(@as(i64, 443), data.server.port);
    try std.testing.expectEqual(true, data.server.ssl);
}

test "spec: flow mapping - empty" {
    const Data = struct {
        empty: ?struct {
            field: ?[]const u8,
        },
    };

    const yaml = "empty: {}\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    _ = data;
    // Empty flow mapping should parse without error
}

test "spec: mixed flow and block" {
    const Data = struct {
        block_key: [][]const u8,
        flow_key: []i64,
    };

    const yaml =
        \\block_key:
        \\  - item1
        \\  - item2
        \\flow_key: [1, 2, 3]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 2), data.block_key.len);
    try std.testing.expectEqual(@as(usize, 3), data.flow_key.len);
    try std.testing.expectEqualStrings("item1", data.block_key[0]);
    try std.testing.expectEqual(@as(i64, 1), data.flow_key[0]);
}

test "spec: flow mapping with quoted values" {
    const Data = struct {
        key1: []const u8,
        key2: []const u8,
    };

    const yaml = "{key1: \"value1\", key2: 'value2'}\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value1", data.key1);
    try std.testing.expectEqualStrings("value2", data.key2);
}

test "spec: flow sequence with quoted strings" {
    const Data = struct {
        items: [][]const u8,
    };

    const yaml = "items: [\"first item\", 'second item', third]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.items.len);
    try std.testing.expectEqualStrings("first item", data.items[0]);
    try std.testing.expectEqualStrings("second item", data.items[1]);
    try std.testing.expectEqualStrings("third", data.items[2]);
}

test "spec: flow mapping in flow sequence" {
    const Item = struct {
        id: i64,
        name: []const u8,
    };

    const Data = struct {
        items: []Item,
    };

    const yaml = "items: [{id: 1, name: first}, {id: 2, name: second}]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 2), data.items.len);
    try std.testing.expectEqual(@as(i64, 1), data.items[0].id);
    try std.testing.expectEqualStrings("first", data.items[0].name);
    try std.testing.expectEqual(@as(i64, 2), data.items[1].id);
    try std.testing.expectEqualStrings("second", data.items[1].name);
}

test "spec: complex flow structures" {
    const Data = struct {
        metadata: struct {
            tags: [][]const u8,
            properties: struct {
                visible: bool,
                priority: i64,
            },
        },
    };

    const yaml = "metadata: {tags: [urgent, bug, frontend], properties: {visible: true, priority: 1}}\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.metadata.tags.len);
    try std.testing.expectEqualStrings("urgent", data.metadata.tags[0]);
    try std.testing.expectEqual(true, data.metadata.properties.visible);
    try std.testing.expectEqual(@as(i64, 1), data.metadata.properties.priority);
}
