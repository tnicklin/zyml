const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

test "decode struct with default values - all fields present" {
    const Config = struct {
        name: []const u8 = "default-app",
        version: []const u8 = "0.0.1",
        port: i64 = 3000,
    };

    const yaml =
        \\name: my-app
        \\version: 1.0.0
        \\port: 8080
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("my-app", config.name);
    try std.testing.expectEqualStrings("1.0.0", config.version);
    try std.testing.expectEqual(@as(i64, 8080), config.port);
}

test "decode struct with default values - some fields missing" {
    const Config = struct {
        name: []const u8 = "default-app",
        version: []const u8 = "0.0.1",
        port: i64 = 3000,
    };

    const yaml =
        \\name: my-app
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("my-app", config.name);
    try std.testing.expectEqualStrings("0.0.1", config.version);
    try std.testing.expectEqual(@as(i64, 3000), config.port);
}

test "decode struct with default values - all fields missing" {
    const Config = struct {
        name: []const u8 = "default-app",
        version: []const u8 = "0.0.1",
        port: i64 = 3000,
    };

    const yaml = "{}";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("default-app", config.name);
    try std.testing.expectEqualStrings("0.0.1", config.version);
    try std.testing.expectEqual(@as(i64, 3000), config.port);
}

test "decode struct with mix of optional and default values" {
    const Config = struct {
        required: []const u8,
        with_default: i64 = 42,
        optional: ?[]const u8 = null,
    };

    const yaml =
        \\required: present
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("present", config.required);
    try std.testing.expectEqual(@as(i64, 42), config.with_default);
    try std.testing.expect(config.optional == null);
}

test "decode nested struct with default values" {
    const Database = struct {
        host: []const u8 = "localhost",
        port: i64 = 5432,
        ssl: bool = false,
    };

    const Config = struct {
        app_name: []const u8 = "my-app",
        database: Database = .{},
    };

    const yaml =
        \\app_name: web-server
        \\database:
        \\  host: db.example.com
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("web-server", config.app_name);
    try std.testing.expectEqualStrings("db.example.com", config.database.host);
    try std.testing.expectEqual(@as(i64, 5432), config.database.port);
    try std.testing.expectEqual(false, config.database.ssl);
}

test "decode nested struct - parent field missing with defaults" {
    const Database = struct {
        host: []const u8 = "localhost",
        port: i64 = 5432,
    };

    const Config = struct {
        app_name: []const u8,
        database: Database = .{},
    };

    const yaml =
        \\app_name: web-server
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("web-server", config.app_name);
    try std.testing.expectEqualStrings("localhost", config.database.host);
    try std.testing.expectEqual(@as(i64, 5432), config.database.port);
}

test "decode empty values vs missing values" {
    const Config = struct {
        explicit_empty: []const u8 = "default",
        missing: []const u8 = "default",
        explicit_null: ?[]const u8 = "default",
    };

    const yaml =
        \\explicit_empty: ""
        \\explicit_null: null
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("", config.explicit_empty);
    try std.testing.expectEqualStrings("default", config.missing);
    try std.testing.expect(config.explicit_null == null);
}

test "decode numeric defaults" {
    const Config = struct {
        int_value: i64 = -1,
        uint_value: u32 = 100,
        float_value: f64 = 3.14,
        bool_value: bool = true,
    };

    const yaml =
        \\int_value: 42
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqual(@as(i64, 42), config.int_value);
    try std.testing.expectEqual(@as(u32, 100), config.uint_value);
    try std.testing.expectEqual(@as(f64, 3.14), config.float_value);
    try std.testing.expectEqual(true, config.bool_value);
}

test "decode array with defaults" {
    const Config = struct {
        tags: [][]const u8 = &.{},
        priority: i64 = 1,
    };

    const yaml1 =
        \\tags: [foo, bar]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    {
        const config = try decoder.decode(Config, yaml1);
        try std.testing.expectEqual(@as(usize, 2), config.tags.len);
        try std.testing.expectEqualStrings("foo", config.tags[0]);
        try std.testing.expectEqualStrings("bar", config.tags[1]);
        try std.testing.expectEqual(@as(i64, 1), config.priority);
    }

    const yaml2 = "priority: 5";
    {
        const config = try decoder.decode(Config, yaml2);
        try std.testing.expectEqual(@as(usize, 0), config.tags.len);
        try std.testing.expectEqual(@as(i64, 5), config.priority);
    }
}

test "decode complex nested structure with defaults" {
    const Retry = struct {
        max_attempts: u32 = 3,
        delay_ms: u32 = 1000,
    };

    const Endpoint = struct {
        url: []const u8,
        timeout_ms: u32 = 5000,
        retry: Retry = .{},
    };

    const Config = struct {
        service_name: []const u8 = "unnamed",
        endpoints: []Endpoint = &.{},
        debug: bool = false,
    };

    const yaml =
        \\service_name: api-gateway
        \\endpoints:
        \\  - url: https://api.example.com
        \\    timeout_ms: 3000
        \\  - url: https://backup.example.com
        \\    retry:
        \\      max_attempts: 5
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("api-gateway", config.service_name);
    try std.testing.expectEqual(@as(usize, 2), config.endpoints.len);
    try std.testing.expectEqualStrings("https://api.example.com", config.endpoints[0].url);
    try std.testing.expectEqual(@as(u32, 3000), config.endpoints[0].timeout_ms);
    try std.testing.expectEqual(@as(u32, 3), config.endpoints[0].retry.max_attempts);
    try std.testing.expectEqual(@as(u32, 1000), config.endpoints[0].retry.delay_ms);
    try std.testing.expectEqualStrings("https://backup.example.com", config.endpoints[1].url);
    try std.testing.expectEqual(@as(u32, 5000), config.endpoints[1].timeout_ms);
    try std.testing.expectEqual(@as(u32, 5), config.endpoints[1].retry.max_attempts);
    try std.testing.expectEqual(@as(u32, 1000), config.endpoints[1].retry.delay_ms);

    try std.testing.expectEqual(false, config.debug);
}

test "decode with hyphenated field names and defaults" {
    const Config = struct {
        app_name: []const u8 = "default",
        max_connections: i64 = 10,
        enable_logging: bool = false,
    };

    const yaml =
        \\app-name: my-service
        \\enable-logging: true
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("my-service", config.app_name);
    try std.testing.expectEqual(@as(i64, 10), config.max_connections);
    try std.testing.expectEqual(true, config.enable_logging);
}

test "decode with zero values vs defaults" {
    const Config = struct {
        count: i64 = 10,
        enabled: bool = true,
        threshold: f64 = 1.5,
    };

    const yaml =
        \\count: 0
        \\enabled: false
        \\threshold: 0.0
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqual(@as(i64, 0), config.count);
    try std.testing.expectEqual(false, config.enabled);
    try std.testing.expectEqual(@as(f64, 0.0), config.threshold);
}

test "decode empty string vs missing string field" {
    const Config = struct {
        name: []const u8 = "default",
        description: []const u8 = "none",
    };

    const yaml =
        \\name: ""
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqualStrings("", config.name);
    try std.testing.expectEqualStrings("none", config.description);
}

test "decode with all types having defaults" {
    const Config = struct {
        a: i32 = 1,
        b: []const u8 = "two",
        c: bool = true,
        d: ?i32 = null,
    };

    const yaml = "{}";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqual(@as(i32, 1), config.a);
    try std.testing.expectEqualStrings("two", config.b);
    try std.testing.expectEqual(true, config.c);
    try std.testing.expect(config.d == null);
}

test "decode override all defaults" {
    const Config = struct {
        a: i32 = 1,
        b: []const u8 = "two",
        c: bool = true,
        d: ?i32 = 99,
    };

    const yaml =
        \\a: 100
        \\b: "custom"
        \\c: false
        \\d: 42
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqual(@as(i32, 100), config.a);
    try std.testing.expectEqualStrings("custom", config.b);
    try std.testing.expectEqual(false, config.c);
    try std.testing.expect(config.d != null);
    try std.testing.expectEqual(@as(i32, 42), config.d.?);
}

test "decode struct with slice defaults" {
    const Config = struct {
        tags: []const []const u8 = &.{ "default", "tags" },
        ports: []const u16 = &.{ 80, 443 },
    };

    const yaml =
        \\tags: [custom]
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(Config, yaml);

    try std.testing.expectEqual(@as(usize, 1), config.tags.len);
    try std.testing.expectEqualStrings("custom", config.tags[0]);
    try std.testing.expectEqual(@as(usize, 2), config.ports.len);
    try std.testing.expectEqual(@as(u16, 80), config.ports[0]);
    try std.testing.expectEqual(@as(u16, 443), config.ports[1]);
}

test "decode real-world config example" {
    const LogConfig = struct {
        level: []const u8 = "info",
        format: []const u8 = "json",
        output: []const u8 = "stdout",
    };

    const ServerConfig = struct {
        host: []const u8 = "0.0.0.0",
        port: u16 = 8080,
        tls_enabled: bool = false,
        tls_cert: ?[]const u8 = null,
        tls_key: ?[]const u8 = null,
    };

    const DatabaseConfig = struct {
        driver: []const u8 = "postgres",
        host: []const u8 = "localhost",
        port: u16 = 5432,
        name: []const u8,
        username: []const u8,
        password: []const u8,
        max_connections: u32 = 25,
        idle_timeout_ms: u32 = 60000,
    };

    const AppConfig = struct {
        environment: []const u8 = "development",
        log: LogConfig = .{},
        server: ServerConfig = .{},
        database: DatabaseConfig,
    };

    const yaml =
        \\environment: production
        \\log:
        \\  level: warn
        \\server:
        \\  port: 443
        \\  tls-enabled: true
        \\  tls-cert: /etc/certs/server.crt
        \\  tls-key: /etc/certs/server.key
        \\database:
        \\  name: myapp_prod
        \\  username: app_user
        \\  password: secret123
        \\  max-connections: 50
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    const config = try decoder.decode(AppConfig, yaml);

    try std.testing.expectEqualStrings("production", config.environment);
    try std.testing.expectEqualStrings("warn", config.log.level);
    try std.testing.expectEqualStrings("json", config.log.format);
    try std.testing.expectEqualStrings("stdout", config.log.output);
    try std.testing.expectEqualStrings("0.0.0.0", config.server.host);
    try std.testing.expectEqual(@as(u16, 443), config.server.port);
    try std.testing.expectEqual(true, config.server.tls_enabled);
    try std.testing.expect(config.server.tls_cert != null);
    try std.testing.expectEqualStrings("/etc/certs/server.crt", config.server.tls_cert.?);
    try std.testing.expect(config.server.tls_key != null);
    try std.testing.expectEqualStrings("/etc/certs/server.key", config.server.tls_key.?);
    try std.testing.expectEqualStrings("postgres", config.database.driver);
    try std.testing.expectEqualStrings("localhost", config.database.host);
    try std.testing.expectEqual(@as(u16, 5432), config.database.port);
    try std.testing.expectEqualStrings("myapp_prod", config.database.name);
    try std.testing.expectEqualStrings("app_user", config.database.username);
    try std.testing.expectEqualStrings("secret123", config.database.password);
    try std.testing.expectEqual(@as(u32, 50), config.database.max_connections);
    try std.testing.expectEqual(@as(u32, 60000), config.database.idle_timeout_ms);
}
