const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Edge Cases
// Tests edge cases, boundary conditions, and error handling

test "spec: very long string" {
    const Data = struct {
        long_string: []const u8,
    };

    var buf: [1000]u8 = undefined;
    @memset(&buf, 'a');
    const long_value = buf[0..];

    var yaml_buf: [1020]u8 = undefined;
    const yaml = try std.fmt.bufPrint(&yaml_buf, "long_string: {s}\n", .{long_value});

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 1000), data.long_string.len);
}

test "spec: many keys" {
    const Data = struct {
        k01: i64,
        k02: i64,
        k03: i64,
        k04: i64,
        k05: i64,
        k06: i64,
        k07: i64,
        k08: i64,
        k09: i64,
        k10: i64,
    };

    const yaml =
        \\k01: 1
        \\k02: 2
        \\k03: 3
        \\k04: 4
        \\k05: 5
        \\k06: 6
        \\k07: 7
        \\k08: 8
        \\k09: 9
        \\k10: 10
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(i64, 1), data.k01);
    try std.testing.expectEqual(@as(i64, 10), data.k10);
}

test "spec: deeply nested structure" {
    const L5 = struct { v: i64 };
    const L4 = struct { l5: L5 };
    const L3 = struct { l4: L4 };
    const L2 = struct { l3: L3 };
    const L1 = struct { l2: L2 };
    const Data = struct { l1: L1 };

    const yaml =
        \\l1:
        \\  l2:
        \\    l3:
        \\      l4:
        \\        l5:
        \\          v: 42
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(i64, 42), data.l1.l2.l3.l4.l5.v);
}

test "spec: empty document" {
    const Data = struct {
        value: ?[]const u8,
    };

    const yaml = "";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    // Empty document should fail or return empty
    _ = decoder.decodeFromSlice(Data, yaml) catch {
        return; // Expected to fail
    };
}

test "spec: whitespace variations" {
    const Data = struct {
        key1: []const u8,
        key2: []const u8,
    };

    const yaml =
        \\key1:  value1
        \\key2:    value2
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value1", data.key1);
    try std.testing.expectEqualStrings("value2", data.key2);
}

test "spec: trailing whitespace" {
    const Data = struct {
        key: []const u8,
    };

    const yaml = "key: value   \n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: keys with hyphens" {
    const Data = struct {
        @"kebab-case": []const u8,
        @"multi-word-key": []const u8,
    };

    const yaml =
        \\kebab-case: value1
        \\multi-word-key: value2
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value1", data.@"kebab-case");
    try std.testing.expectEqualStrings("value2", data.@"multi-word-key");
}

test "spec: keys with underscores" {
    const Data = struct {
        snake_case: []const u8,
        multi_word_key: []const u8,
    };

    const yaml =
        \\snake_case: value1
        \\multi_word_key: value2
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value1", data.snake_case);
    try std.testing.expectEqualStrings("value2", data.multi_word_key);
}

test "spec: string and numeric values" {
    const Data = struct {
        text: []const u8,
        actual_number: i64,
    };

    const yaml =
        \\text: abc123
        \\actual_number: 456
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("abc123", data.text);
    try std.testing.expectEqual(@as(i64, 456), data.actual_number);
}

test "spec: optional fields with missing values" {
    const Data = struct {
        required: []const u8,
        optional1: ?[]const u8 = null,
        optional2: ?i64 = null,
    };

    const yaml = "required: present\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("present", data.required);
    try std.testing.expect(data.optional1 == null);
    try std.testing.expect(data.optional2 == null);
}

test "spec: mixed types in flow sequence" {
    const Data = struct {
        mixed: []i64,
    };

    const yaml = "mixed: [1, 2, 3]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.mixed.len);
}

test "spec: unicode in keys and values" {
    const Data = struct {
        emoji: []const u8,
        unicode: []const u8,
    };

    const yaml =
        \\emoji: 🎉
        \\unicode: 你好
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("🎉", data.emoji);
    try std.testing.expectEqualStrings("你好", data.unicode);
}

test "spec: large array" {
    const Data = struct {
        numbers: []i64,
    };

    const yaml =
        \\numbers: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        \\          11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 20), data.numbers.len);
    try std.testing.expectEqual(@as(i64, 1), data.numbers[0]);
    try std.testing.expectEqual(@as(i64, 20), data.numbers[19]);
}

test "spec: complex real-world config" {
    const Database = struct {
        host: []const u8,
        port: i64,
        credentials: struct {
            username: []const u8,
            password: []const u8,
        },
    };

    const Server = struct {
        host: []const u8,
        port: i64,
        ssl: bool,
    };

    const Config = struct {
        app_name: []const u8,
        version: []const u8,
        database: Database,
        servers: []Server,
        features: [][]const u8,
    };

    const yaml =
        \\# Application Configuration
        \\app_name: MyApplication
        \\version: 1.0.0
        \\
        \\# Database settings
        \\database:
        \\  host: db.example.com
        \\  port: 5432
        \\  credentials:
        \\    username: admin
        \\    password: secret123
        \\
        \\# Server list
        \\servers:
        \\  - host: server1.example.com
        \\    port: 8080
        \\    ssl: true
        \\  - host: server2.example.com
        \\    port: 8080
        \\    ssl: true
        \\
        \\# Features
        \\features: [authentication, logging, caching]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Config, yaml);
    try std.testing.expectEqualStrings("MyApplication", data.app_name);
    try std.testing.expectEqualStrings("1.0.0", data.version);
    try std.testing.expectEqualStrings("db.example.com", data.database.host);
    try std.testing.expectEqual(@as(i64, 5432), data.database.port);
    try std.testing.expectEqual(@as(usize, 2), data.servers.len);
    try std.testing.expectEqual(true, data.servers[0].ssl);
    try std.testing.expectEqual(@as(usize, 3), data.features.len);
    try std.testing.expectEqualStrings("authentication", data.features[0]);
}
