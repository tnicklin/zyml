const std = @import("std");
const zyml = @import("zyml");
const Encoder = zyml.Encoder;
const Decoder = zyml.Decoder;

test "encode simple struct" {
    const Config = struct {
        name: []const u8,
        version: []const u8,
        port: i64,
    };

    const config = Config{
        .name = "my-app",
        .version = "1.0.0",
        .port = 8080,
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "name: my-app") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "version: 1.0.0") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "port: 8080") != null);
}

test "encode nested struct" {
    const Database = struct {
        host: []const u8,
        port: i64,
    };

    const Config = struct {
        app_name: []const u8,
        database: Database,
    };

    const config = Config{
        .app_name = "web-server",
        .database = .{
            .host = "localhost",
            .port = 5432,
        },
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "app_name: web-server") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "database:") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "host: localhost") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "port: 5432") != null);
}

test "encode array" {
    const Config = struct {
        features: []const []const u8,
    };

    const features = [_][]const u8{ "BGP", "OSPF", "eBPF" };
    const config = Config{
        .features = &features,
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "features:") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "BGP") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "OSPF") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "eBPF") != null);
}

test "encode and decode roundtrip" {
    const Config = struct {
        name: []const u8,
        port: i64,
        enabled: bool,
    };

    const original = Config{
        .name = "test-app",
        .port = 3000,
        .enabled = true,
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(original);
    defer std.testing.allocator.free(yaml);

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const decoded = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings(original.name, decoded.name);
    try std.testing.expectEqual(original.port, decoded.port);
    try std.testing.expectEqual(original.enabled, decoded.enabled);
}

test "encode numeric types" {
    const Config = struct {
        int_val: i32,
        uint_val: u32,
        float_val: f64,
        bool_val: bool,
    };

    const config = Config{
        .int_val = -42,
        .uint_val = 100,
        .float_val = 3.14,
        .bool_val = true,
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "-42") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "100") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "3.14") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "true") != null);
}

test "encode to file" {
    const Config = struct {
        test_field: []const u8,
    };

    const config = Config{
        .test_field = "from_encoder",
    };

    const test_file_path = "test_encoder.yaml";

    std.fs.cwd().deleteFile(test_file_path) catch {};

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    try encoder.encodeToFile(test_file_path, config);
    defer std.fs.cwd().deleteFile(test_file_path) catch {};

    const file = try std.fs.cwd().openFile(test_file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(std.testing.allocator, 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "test_field: from_encoder") != null);
}

test "encode optional fields" {
    const Config = struct {
        required: []const u8,
        optional_present: ?[]const u8,
        optional_null: ?[]const u8,
    };

    const config = Config{
        .required = "present",
        .optional_present = "also_present",
        .optional_null = null,
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "required: present") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "optional_present: also_present") != null);
}

test "encode multiple documents" {
    const Config = struct {
        name: []const u8,
    };

    const configs = [_]Config{
        .{ .name = "doc1" },
        .{ .name = "doc2" },
        .{ .name = "doc3" },
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encodeAll(configs);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "---") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "name: doc1") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "name: doc2") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "name: doc3") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "...") != null);
}

test "encode complex nested structure" {
    const Retry = struct {
        max_attempts: u32,
        delay_ms: u32,
    };

    const Endpoint = struct {
        url: []const u8,
        timeout_ms: u32,
        retry: Retry,
    };

    const Config = struct {
        service_name: []const u8,
        endpoints: []const Endpoint,
        debug: bool,
    };

    const endpoints = [_]Endpoint{
        .{
            .url = "https://api.example.com",
            .timeout_ms = 3000,
            .retry = .{ .max_attempts = 3, .delay_ms = 1000 },
        },
        .{
            .url = "https://backup.example.com",
            .timeout_ms = 5000,
            .retry = .{ .max_attempts = 5, .delay_ms = 2000 },
        },
    };

    const config = Config{
        .service_name = "api-gateway",
        .endpoints = &endpoints,
        .debug = false,
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "service_name: api-gateway") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "endpoints:") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "url: https://api.example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "url: https://backup.example.com") != null);
}

test "convenience encode function" {
    const Config = struct {
        value: i64,
    };

    const config = Config{ .value = 42 };

    var result = try zyml.encode(std.testing.allocator, config);
    defer {
        std.testing.allocator.free(result.yaml);
        result.arena.deinit();
    }

    try std.testing.expect(std.mem.indexOf(u8, result.yaml, "value: 42") != null);
}

test "encode empty struct" {
    const Config = struct {};

    const config = Config{};

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    // Empty struct should produce empty or minimal YAML
    try std.testing.expect(yaml.len < 10);
}

test "encode with zero values" {
    const Config = struct {
        count: i32,
        enabled: bool,
        name: []const u8,
    };

    const config = Config{
        .count = 0,
        .enabled = false,
        .name = "",
    };

    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const yaml = try encoder.encode(config);
    defer std.testing.allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "count: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "enabled: false") != null);
}
