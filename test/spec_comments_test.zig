const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Comments
// Tests comment handling in various contexts

test "spec: full-line comment" {
    const Data = struct {
        key: []const u8,
    };

    const yaml =
        \\# This is a comment
        \\key: value
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: inline comment" {
    const Data = struct {
        key: []const u8,
    };

    const yaml = "key: value  # inline comment\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: multiple inline comments" {
    const Data = struct {
        host: []const u8,
        port: i64,
    };

    const yaml =
        \\host: localhost  # server address
        \\port: 8080       # listen port
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("localhost", data.host);
    try std.testing.expectEqual(@as(i64, 8080), data.port);
}

test "spec: comment before value" {
    const Data = struct {
        key1: []const u8,
        key2: []const u8,
    };

    const yaml =
        \\key1: value1
        \\# Comment between values
        \\key2: value2
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value1", data.key1);
    try std.testing.expectEqualStrings("value2", data.key2);
}

test "spec: comments in nested structures" {
    const Config = struct {
        server: struct {
            host: []const u8,
            port: i64,
        },
    };

    const yaml =
        \\# Server configuration
        \\server:
        \\  # Connection details
        \\  host: localhost
        \\  port: 8080  # Default port
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Config, yaml);
    try std.testing.expectEqualStrings("localhost", data.server.host);
    try std.testing.expectEqual(@as(i64, 8080), data.server.port);
}

test "spec: comments in lists" {
    const Data = struct {
        items: [][]const u8,
    };

    const yaml =
        \\# List of items
        \\items:
        \\  # First item
        \\  - apple
        \\  - banana  # yellow fruit
        \\  # Last item
        \\  - cherry
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.items.len);
    try std.testing.expectEqualStrings("apple", data.items[0]);
    try std.testing.expectEqualStrings("banana", data.items[1]);
    try std.testing.expectEqualStrings("cherry", data.items[2]);
}

test "spec: empty comment" {
    const Data = struct {
        key: []const u8,
    };

    const yaml =
        \\#
        \\key: value
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: comment-only lines" {
    const Data = struct {
        a: []const u8,
        b: []const u8,
    };

    const yaml =
        \\# Header
        \\#
        \\a: value_a
        \\#
        \\# Middle
        \\#
        \\b: value_b
        \\#
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value_a", data.a);
    try std.testing.expectEqualStrings("value_b", data.b);
}

test "spec: comment with special characters" {
    const Data = struct {
        key: []const u8,
    };

    const yaml = "key: value  # @#$%^&*() special chars\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: comments around document markers" {
    const Data = struct {
        value: []const u8,
    };

    const yaml =
        \\# Document start
        \\---
        \\# Content
        \\value: data
        \\# Document end
        \\...
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("data", data.value);
}

test "spec: multiple consecutive comments" {
    const Data = struct {
        key: []const u8,
    };

    const yaml =
        \\# Comment line 1
        \\# Comment line 2
        \\# Comment line 3
        \\key: value
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

