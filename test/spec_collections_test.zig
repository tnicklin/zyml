const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Collections
// Tests sequences (lists) and mappings (dictionaries)

test "spec: simple sequence" {
    const Data = struct {
        items: [][]const u8,
    };

    const yaml =
        \\items:
        \\  - apple
        \\  - banana
        \\  - cherry
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.items.len);
    try std.testing.expectEqualStrings("apple", data.items[0]);
    try std.testing.expectEqualStrings("banana", data.items[1]);
    try std.testing.expectEqualStrings("cherry", data.items[2]);
}

test "spec: sequence of numbers" {
    const Data = struct {
        numbers: []i64,
    };

    const yaml =
        \\numbers:
        \\  - 1
        \\  - 2
        \\  - 3
        \\  - 42
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 4), data.numbers.len);
    try std.testing.expectEqual(@as(i64, 1), data.numbers[0]);
    try std.testing.expectEqual(@as(i64, 42), data.numbers[3]);
}

test "spec: nested sequences" {
    const Data = struct {
        matrix: [][]i64,
    };

    const yaml =
        \\matrix:
        \\  - [1, 2, 3]
        \\  - [4, 5, 6]
        \\  - [7, 8, 9]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.matrix.len);
    try std.testing.expectEqual(@as(usize, 3), data.matrix[0].len);
    try std.testing.expectEqual(@as(i64, 1), data.matrix[0][0]);
    try std.testing.expectEqual(@as(i64, 5), data.matrix[1][1]);
    try std.testing.expectEqual(@as(i64, 9), data.matrix[2][2]);
}

test "spec: simple mapping" {
    const Data = struct {
        name: []const u8,
        age: i64,
        city: []const u8,
    };

    const yaml =
        \\name: John Doe
        \\age: 30
        \\city: New York
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("John Doe", data.name);
    try std.testing.expectEqual(@as(i64, 30), data.age);
    try std.testing.expectEqualStrings("New York", data.city);
}

test "spec: nested mappings" {
    const Address = struct {
        street: []const u8,
        city: []const u8,
        zip: i64,
    };

    const Person = struct {
        name: []const u8,
        address: Address,
    };

    const yaml =
        \\name: Jane Smith
        \\address:
        \\  street: 123 Main St
        \\  city: Boston
        \\  zip: 02101
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Person, yaml);
    try std.testing.expectEqualStrings("Jane Smith", data.name);
    try std.testing.expectEqualStrings("123 Main St", data.address.street);
    try std.testing.expectEqualStrings("Boston", data.address.city);
    try std.testing.expectEqual(@as(i64, 2101), data.address.zip);
}

test "spec: sequence of mappings" {
    const Item = struct {
        name: []const u8,
        price: f64,
    };

    const Data = struct {
        products: []Item,
    };

    const yaml =
        \\products:
        \\  - name: Widget
        \\    price: 9.99
        \\  - name: Gadget
        \\    price: 19.99
        \\  - name: Gizmo
        \\    price: 29.99
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.products.len);
    try std.testing.expectEqualStrings("Widget", data.products[0].name);
    try std.testing.expectEqual(@as(f64, 9.99), data.products[0].price);
    try std.testing.expectEqualStrings("Gizmo", data.products[2].name);
}

test "spec: mapping of sequences" {
    const Data = struct {
        fruits: [][]const u8,
        vegetables: [][]const u8,
    };

    const yaml =
        \\fruits:
        \\  - apple
        \\  - banana
        \\vegetables:
        \\  - carrot
        \\  - broccoli
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 2), data.fruits.len);
    try std.testing.expectEqual(@as(usize, 2), data.vegetables.len);
    try std.testing.expectEqualStrings("apple", data.fruits[0]);
    try std.testing.expectEqualStrings("carrot", data.vegetables[0]);
}

test "spec: deeply nested structures" {
    const Level3 = struct {
        value: []const u8,
    };

    const Level2 = struct {
        level3: Level3,
    };

    const Level1 = struct {
        level2: Level2,
    };

    const Data = struct {
        level1: Level1,
    };

    const yaml =
        \\level1:
        \\  level2:
        \\    level3:
        \\      value: deep
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("deep", data.level1.level2.level3.value);
}

test "spec: empty collections" {
    const Data = struct {
        empty_list: [][]const u8,
        empty_map: ?struct {
            field: ?[]const u8,
        },
    };

    const yaml =
        \\empty_list: []
        \\empty_map: {}
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 0), data.empty_list.len);
}

test "spec: mixed indentation levels" {
    const Config = struct {
        database: struct {
            host: []const u8,
            port: i64,
            credentials: struct {
                username: []const u8,
                password: []const u8,
            },
        },
        server: struct {
            port: i64,
        },
    };

    const yaml =
        \\database:
        \\  host: localhost
        \\  port: 5432
        \\  credentials:
        \\    username: admin
        \\    password: secret
        \\server:
        \\  port: 8080
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Config, yaml);
    try std.testing.expectEqualStrings("localhost", data.database.host);
    try std.testing.expectEqual(@as(i64, 5432), data.database.port);
    try std.testing.expectEqualStrings("admin", data.database.credentials.username);
    try std.testing.expectEqual(@as(i64, 8080), data.server.port);
}
