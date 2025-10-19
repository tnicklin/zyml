const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

test "decode simple struct from string" {
    const Config = struct {
        name: []const u8,
        version: []const u8,
        port: i64,
    };

    const yaml =
        \\name: my-app
        \\version: 1.0.0
        \\port: 8080
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decodeFromSlice(Config, yaml);

    try std.testing.expectEqualStrings("my-app", config.name);
    try std.testing.expectEqualStrings("1.0.0", config.version);
    try std.testing.expectEqual(@as(i64, 8080), config.port);
}

test "decode nested struct" {
    const Database = struct {
        host: []const u8,
        port: i64,
    };

    const Config = struct {
        app_name: []const u8,
        database: Database,
    };

    const yaml =
        \\app_name: web-server
        \\database:
        \\  host: localhost
        \\  port: 5432
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decodeFromSlice(Config, yaml);

    try std.testing.expectEqualStrings("web-server", config.app_name);
    try std.testing.expectEqualStrings("localhost", config.database.host);
    try std.testing.expectEqual(@as(i64, 5432), config.database.port);
}

test "decode array/list" {
    const Config = struct {
        features: [][]const u8,
    };

    const yaml =
        \\features:
        \\  - BGP
        \\  - OSPF
        \\  - eBPF
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decodeFromSlice(Config, yaml);

    try std.testing.expectEqual(@as(usize, 3), config.features.len);
    try std.testing.expectEqualStrings("BGP", config.features[0]);
    try std.testing.expectEqualStrings("OSPF", config.features[1]);
    try std.testing.expectEqualStrings("eBPF", config.features[2]);
}

test "decode with flow collections" {
    const Metadata = struct {
        type: []const u8,
        dimension: []const u8,
    };

    const Point = struct {
        coords: []i64,
        metadata: Metadata,
    };

    const yaml =
        \\coords: [10, 20, 30]
        \\metadata: {type: point, dimension: 3d}
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const point = try decoder.decodeFromSlice(Point, yaml);

    try std.testing.expectEqual(@as(usize, 3), point.coords.len);
    try std.testing.expectEqual(@as(i64, 10), point.coords[0]);
    try std.testing.expectEqual(@as(i64, 20), point.coords[1]);
    try std.testing.expectEqual(@as(i64, 30), point.coords[2]);

    try std.testing.expectEqualStrings("point", point.metadata.type);
    try std.testing.expectEqualStrings("3d", point.metadata.dimension);
}

test "decode multiple documents" {
    const Config = struct {
        name: []const u8,
    };

    const yaml =
        \\---
        \\name: doc1
        \\---
        \\name: doc2
        \\---
        \\name: doc3
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const configs = try decoder.decodeAllFromSlice(Config, yaml);

    try std.testing.expectEqual(@as(usize, 3), configs.len);
    try std.testing.expectEqualStrings("doc1", configs[0].name);
    try std.testing.expectEqualStrings("doc2", configs[1].name);
    try std.testing.expectEqualStrings("doc3", configs[2].name);
}

test "decode from file" {
    const Config = struct {
        test_field: []const u8,
    };

    const test_yaml = "test_field: from_file\n";
    const test_file_path = "test_decoder.yaml";

    {
        const file = try std.fs.cwd().createFile(test_file_path, .{});
        defer file.close();
        try file.writeAll(test_yaml);
    }
    defer std.fs.cwd().deleteFile(test_file_path) catch {};

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decodeFromFile(Config, test_file_path);

    try std.testing.expectEqualStrings("from_file", config.test_field);
}

test "decode with comments" {
    const Config = struct {
        host: []const u8,
        port: i64,
    };

    const yaml =
        \\# Server configuration
        \\host: localhost  # bind address
        \\port: 3000       # listen port
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decodeFromSlice(Config, yaml);

    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(i64, 3000), config.port);
}

test "decode with block scalars" {
    const Config = struct {
        description: []const u8,
        summary: []const u8,
    };

    const yaml =
        \\description: |
        \\  This is a multi-line
        \\  literal block scalar
        \\  that preserves newlines.
        \\summary: >
        \\  This is a folded
        \\  block scalar that
        \\  joins lines with spaces.
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decodeFromSlice(Config, yaml);

    // Description should have newlines preserved
    try std.testing.expect(std.mem.indexOf(u8, config.description, "\n") != null);

    // Summary should be folded (no newlines except trailing)
    const summary_no_trailing = std.mem.trimRight(u8, config.summary, "\n");
    try std.testing.expect(std.mem.indexOf(u8, summary_no_trailing, "\n") == null);
}

test "convenience decode function" {
    const Config = struct {
        value: i64,
    };

    const yaml = "value: 42\n";

    var result = try zyml.decode(std.testing.allocator, Config, yaml);
    defer result.arena.deinit();

    try std.testing.expectEqual(@as(i64, 42), result.value.value);
}

test "decode with optional fields" {
    const Config = struct {
        required: []const u8,
        optional: ?[]const u8 = null,
    };

    const yaml1 =
        \\required: present
        \\optional: also_present
    ;

    const yaml2 =
        \\required: present
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    {
        const config = try decoder.decodeFromSlice(Config, yaml1);

        try std.testing.expectEqualStrings("present", config.required);
        try std.testing.expect(config.optional != null);
        try std.testing.expectEqualStrings("also_present", config.optional.?);
    }

    {
        const config = try decoder.decodeFromSlice(Config, yaml2);

        try std.testing.expectEqualStrings("present", config.required);
        try std.testing.expect(config.optional == null);
    }
}
