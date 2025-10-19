const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Documents
// Tests document markers (---), document end (...), and multiple documents

test "spec: document with start marker" {
    const Data = struct {
        key: []const u8,
    };

    const yaml =
        \\---
        \\key: value
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: document with start and end markers" {
    const Data = struct {
        key: []const u8,
    };

    const yaml =
        \\---
        \\key: value
        \\...
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("value", data.key);
}

test "spec: multiple documents" {
    const Data = struct {
        id: i64,
    };

    const yaml =
        \\---
        \\id: 1
        \\---
        \\id: 2
        \\---
        \\id: 3
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const docs = try decoder.decodeAllFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), docs.len);
    try std.testing.expectEqual(@as(i64, 1), docs[0].id);
    try std.testing.expectEqual(@as(i64, 2), docs[1].id);
    try std.testing.expectEqual(@as(i64, 3), docs[2].id);
}

test "spec: multiple documents with end markers" {
    const Data = struct {
        value: []const u8,
    };

    const yaml =
        \\---
        \\value: first
        \\...
        \\---
        \\value: second
        \\...
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const docs = try decoder.decodeAllFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 2), docs.len);
    try std.testing.expectEqualStrings("first", docs[0].value);
    try std.testing.expectEqualStrings("second", docs[1].value);
}

test "spec: mixed document markers" {
    const Data = struct {
        name: []const u8,
    };

    const yaml =
        \\---
        \\name: doc1
        \\---
        \\name: doc2
        \\...
        \\---
        \\name: doc3
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const docs = try decoder.decodeAllFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(usize, 3), docs.len);
    try std.testing.expectEqualStrings("doc1", docs[0].name);
    try std.testing.expectEqualStrings("doc2", docs[1].name);
    try std.testing.expectEqualStrings("doc3", docs[2].name);
}

test "spec: document without explicit marker" {
    const Data = struct {
        implicit: []const u8,
    };

    const yaml = "implicit: document\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("document", data.implicit);
}

test "spec: multiple documents with different structures" {
    const Doc1 = struct {
        type: []const u8,
        count: i64,
    };

    const yaml =
        \\---
        \\type: config
        \\count: 1
        \\---
        \\type: data
        \\count: 2
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const docs = try decoder.decodeAllFromSlice(Doc1, yaml);
    try std.testing.expectEqual(@as(usize, 2), docs.len);
    try std.testing.expectEqualStrings("config", docs[0].type);
    try std.testing.expectEqual(@as(i64, 1), docs[0].count);
    try std.testing.expectEqualStrings("data", docs[1].type);
    try std.testing.expectEqual(@as(i64, 2), docs[1].count);
}

test "spec: multiple documents with complex content" {
    const Server = struct {
        host: []const u8,
        port: i64,
    };

    const yaml =
        \\---
        \\host: server1
        \\port: 8080
        \\---
        \\host: server2
        \\port: 8081
        \\---
        \\host: server3
        \\port: 8082
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const servers = try decoder.decodeAllFromSlice(Server, yaml);
    try std.testing.expectEqual(@as(usize, 3), servers.len);
    try std.testing.expectEqualStrings("server1", servers[0].host);
    try std.testing.expectEqual(@as(i64, 8080), servers[0].port);
    try std.testing.expectEqualStrings("server3", servers[2].host);
    try std.testing.expectEqual(@as(i64, 8082), servers[2].port);
}

test "spec: document markers with empty lines" {
    const Data = struct {
        value: []const u8,
    };

    const yaml =
        \\---
        \\
        \\value: data
        \\
        \\...
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("data", data.value);
}

