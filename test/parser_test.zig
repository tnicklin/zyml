const std = @import("std");
const zyml = @import("zyml");
const Parser = zyml.Parser;

test "parse simple literal block scalar" {
    const source =
        \\key: |
        \\  line 1
        \\  line 2
        \\  line 3
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse simple folded block scalar" {
    const source =
        \\key: >
        \\  line 1
        \\  line 2
        \\  line 3
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse literal block with empty lines" {
    const source =
        \\description: |
        \\  First paragraph
        \\
        \\  Second paragraph
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse multiple keys with block scalars" {
    const source =
        \\key1: |
        \\  value 1
        \\key2: >
        \\  value 2
        \\key3: simple
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse nested map with block scalar" {
    const source =
        \\parent:
        \\  child: |
        \\    nested value
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse quoted strings" {
    const source =
        \\single: 'hello world'
        \\double: "hello\nworld"
        \\escape: "with \"quotes\""
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse list with various value types" {
    const source =
        \\items:
        \\  - simple
        \\  - 'quoted'
        \\  - "double"
        \\  - 123
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse flow sequences" {
    const source =
        \\inline: [a, b, c]
        \\multiline: [
        \\  x,
        \\  y,
        \\  z
        \\]
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse flow mappings" {
    const source =
        \\inline: {a: 1, b: 2, c: 3}
        \\multiline: {
        \\  x: 1,
        \\  y: 2
        \\}
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse explicit document markers" {
    const source =
        \\---
        \\key: value
        \\...
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse multiple documents" {
    const source =
        \\---
        \\key1: value1
        \\---
        \\key2: value2
        \\---
        \\key3: value3
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), tree.docs.len);
}

test "parse comments" {
    const source =
        \\# This is a comment
        \\key: value  # inline comment
        \\# another comment
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse inline comments" {
    const source =
        \\key1: value1  # comment 1
        \\key2: value2  # comment 2
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse deeply nested structure" {
    const source =
        \\level1:
        \\  level2:
        \\    level3:
        \\      key: value
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse empty values" {
    const source =
        \\key1:
        \\key2:
        \\key3: value
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse mixed indentation list" {
    const source =
        \\items:
        \\  - item1
        \\  - nested:
        \\      value: 2
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse escape sequences in double quotes" {
    const source =
        \\escaped: "newline\ntab\there"
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}

test "parse escape sequences in single quotes" {
    const source =
        \\escaped: 'it''s a test'
    ;

    var parser = try Parser.init(std.testing.allocator, source);
    defer parser.deinit(std.testing.allocator);

    try parser.parse(std.testing.allocator);
    var tree = try parser.toOwnedTree(std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.docs.len);
}
