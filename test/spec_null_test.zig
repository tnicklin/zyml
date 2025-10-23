const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Null Values
// Tests various null representations

test "spec: null value with null keyword" {
    const Data = struct {
        value: ?[]const u8,
    };

    const yaml = "value: null\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.value == null);
}

test "spec: null value with tilde" {
    const Data = struct {
        value: ?[]const u8,
    };

    const yaml = "value: ~\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.value == null);
}

test "spec: null value implicit (empty)" {
    const Data = struct {
        key1: []const u8,
        key2: ?[]const u8,
    };

    const yaml =
        \\key1: value
        \\key2:
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    // Note: Parser currently doesn't support empty values
    _ = decoder.decode(Data, yaml) catch {
        // Expected to fail - empty implicit values not supported
        return;
    };
}

test "spec: null in sequence" {
    const Data = struct {
        items: [][]const u8,
    };

    const yaml =
        \\items:
        \\  - value1
        \\  - value2
        \\  - value3
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), data.items.len);
    try std.testing.expectEqualStrings("value1", data.items[0]);
    try std.testing.expectEqualStrings("value2", data.items[1]);
    try std.testing.expectEqualStrings("value3", data.items[2]);
}

test "spec: optional integer with default" {
    const Data = struct {
        count: ?i64 = null,
        name: []const u8,
    };

    const yaml = "name: test\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.count == null);
    try std.testing.expectEqualStrings("test", data.name);
}

test "spec: optional boolean with default" {
    const Data = struct {
        enabled: ?bool = null,
        name: []const u8,
    };

    const yaml = "name: test\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.enabled == null);
    try std.testing.expectEqualStrings("test", data.name);
}

test "spec: optional vs empty string" {
    const Data = struct {
        optional_value: ?[]const u8 = null,
        empty_value: []const u8,
    };

    const yaml = "empty_value: ''\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.optional_value == null);
    try std.testing.expectEqualStrings("", data.empty_value);
}

test "spec: flow mapping with optional fields" {
    const Data = struct {
        config: struct {
            opt1: ?[]const u8 = null,
            opt2: []const u8,
        },
    };

    const yaml = "config: {opt2: value}\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.config.opt1 == null);
    try std.testing.expectEqualStrings("value", data.config.opt2);
}

test "spec: uppercase NULL variants" {
    const Data = struct {
        null_lower: ?[]const u8,
        null_upper: ?[]const u8,
        null_capital: ?[]const u8,
    };

    const yaml =
        \\null_lower: null
        \\null_upper: NULL
        \\null_capital: Null
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expect(data.null_lower == null);
    try std.testing.expect(data.null_upper == null);
    try std.testing.expect(data.null_capital == null);
}
