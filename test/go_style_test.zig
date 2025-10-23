const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

test "missing fields get zero values" {
    const Config = struct {
        host: []const u8,
        port: u16,
        timeout_ms: u32,
        enabled: bool,
        max_connections: i32,
    };

    const yaml = "host: example.com\nport: 3000";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("example.com", config.host);
    try std.testing.expectEqual(@as(u16, 3000), config.port);

    try std.testing.expectEqual(@as(u32, 0), config.timeout_ms);
    try std.testing.expectEqual(false, config.enabled);
    try std.testing.expectEqual(@as(i32, 0), config.max_connections);
}

test "Go-style: nested structs with zero values" {
    const DatabaseConfig = struct {
        host: []const u8,
        port: u16,
        ssl_enabled: bool,
    };

    const Config = struct {
        service_name: []const u8,
        database: DatabaseConfig,
        max_retries: u32,
    };

    const yaml =
        \\service_name: my-service
        \\database:
        \\  host: db.example.com
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("my-service", config.service_name);
    try std.testing.expectEqualStrings("db.example.com", config.database.host);

    // Missing nested fields get zero values
    try std.testing.expectEqual(@as(u16, 0), config.database.port);
    try std.testing.expectEqual(false, config.database.ssl_enabled);
    try std.testing.expectEqual(@as(u32, 0), config.max_retries);
}

test "Go-style: explicit defaults override zero values" {
    // When you DO specify defaults, they take precedence over zero values
    const Config = struct {
        host: []const u8 = "localhost", // Explicit default
        port: u16 = 8080, // Explicit default
        timeout_ms: u32, // Will be zero
        enabled: bool, // Will be false
    };

    const yaml = "{}"; // Empty config

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    // Explicit defaults used
    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(u16, 8080), config.port);

    // No explicit defaults → zero values
    try std.testing.expectEqual(@as(u32, 0), config.timeout_ms);
    try std.testing.expectEqual(false, config.enabled);
}

test "Go-style: empty slices for missing arrays" {
    const Config = struct {
        name: []const u8,
        tags: [][]const u8,
        ports: []u16,
    };

    const yaml = "name: test";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("test", config.name);

    // Missing slice fields become empty slices (zero value)
    try std.testing.expectEqual(@as(usize, 0), config.tags.len);
    try std.testing.expectEqual(@as(usize, 0), config.ports.len);
}

test "Go-style: real world config without explicit defaults" {
    const StateDBConfig = struct {
        host: []const u8,
        port: u16,
        timeout_ms: u32,
        max_connections: u32,
    };

    const RoutingConfig = struct {
        protocol: []const u8,
        cost_metric: u32,
        hello_interval_ms: u32,
    };

    const Config = struct {
        node_id: []const u8,
        statedb: StateDBConfig,
        routing: RoutingConfig,
        debug_enabled: bool,
    };

    // Minimal config - most fields missing
    const yaml =
        \\node_id: node-1
        \\statedb:
        \\  host: db-server
        \\routing:
        \\  protocol: ospf
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    // Provided fields
    try std.testing.expectEqualStrings("node-1", config.node_id);
    try std.testing.expectEqualStrings("db-server", config.statedb.host);
    try std.testing.expectEqualStrings("ospf", config.routing.protocol);

    // Missing fields automatically get zero values (like Go!)
    try std.testing.expectEqual(@as(u16, 0), config.statedb.port);
    try std.testing.expectEqual(@as(u32, 0), config.statedb.timeout_ms);
    try std.testing.expectEqual(@as(u32, 0), config.statedb.max_connections);
    try std.testing.expectEqual(@as(u32, 0), config.routing.cost_metric);
    try std.testing.expectEqual(@as(u32, 0), config.routing.hello_interval_ms);
    try std.testing.expectEqual(false, config.debug_enabled);
}
