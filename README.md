# zyml - YAML Parser for Zig

A robust, YAML 1.2 compliant parser written in Zig.

## Features

### Fully Implemented
- **Scalars**: Double-quoted, single-quoted, and plain
- **Escape Sequences**: `\n` (newline), `\t` (tab), `\"` (quote), `''` (single quote escape)
- **Collections**: Block sequences, block mappings, flow sequences, **flow mappings**
- **Documents**: Multiple documents, explicit markers (`---`, `...`)
- **Comments**: Full line and inline comments (all edge cases resolved)
- **Block Scalars**: Literal (`|`) and folded (`>`) with proper indentation
- **Block Scalar Indicators**: Chomping (`|-`, `|+`) and explicit indentation (`|2`, `>3`, etc.)
- **Null Values**: `null`, `~`, `Null`, `NULL` (properly parsed as null/empty values)
- **Nesting**: Arbitrarily deep nested structures
- **Numeric Types**: Integers, floats, scientific notation (e.g., `1.5e3`)
- **Booleans**: `true` and `false` literals
- **Unicode**: Full UTF-8 support including emoji and non-Latin characters

### Not Yet Implemented
- **Escape Sequences**: `\\` (backslash), `\r` (carriage return), `\xNN`, `\uNNNN`, `\UNNNNNNNN`
- **Special Numeric Formats**: Hexadecimal (`0xFF`), octal (`0o777`), binary (`0b1010`)
- **Special Float Values**: `.inf`, `-.inf`, `.nan`
- **Anchors and Aliases**: `&anchor`, `*alias`
- **Tags**: `!!str`, `!!int`, `!!map`, etc.
- **Complex Mapping Keys**: Non-scalar keys
- **Directives**: `%YAML`, `%TAG`

## Decoder API

```zig
const std = @import("std");
const zyml = @import("zyml");

const Config = struct {
    name: []const u8,
    version: []const u8,
    features: [][]const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var decoder = zyml.Decoder.init(gpa.allocator());
    defer decoder.deinit(); // Single call frees all memory

    const yaml =
        \\name: foo-bar
        \\version: 4.2.0
        \\features: [BGP, OSPF, eBPF]
    ;

    const config = try decoder.decodeFromSlice(Config, yaml);
    std.debug.print("App: {s} v{s}\n", .{config.name, config.version});
}
```

## Encoder API

```zig
const std = @import("std");
const zyml = @import("zyml");

const Config = struct {
    name: []const u8,
    version: []const u8,
    port: i64,
    enabled: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var encoder = zyml.Encoder.init(gpa.allocator());
    defer encoder.deinit();

    const config = Config{
        .name = "my-app",
        .version = "2.0.0",
        .port = 8080,
        .enabled = true,
    };

    // Encode to string
    const yaml = try encoder.encode(config);
    defer gpa.allocator().free(yaml);

    std.debug.print("{s}\n", .{yaml});

    // Or encode directly to file
    try encoder.encodeToFile("config.yaml", config);
}
```

### Roundtrip Example

```zig
// Decode YAML → Struct
var decoder = zyml.Decoder.init(allocator);
defer decoder.deinit();
const config = try decoder.decodeFromSlice(Config, yaml_string);

// Encode Struct → YAML
var encoder = zyml.Encoder.init(allocator);
defer encoder.deinit();
const yaml = try encoder.encode(config);
```

## Low-Level API

```zig
const std = @import("std");
const Yaml = @import("zyml").Yaml;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "name: foo-bar\nversion: 4.2.0\n";

    var yaml = Yaml{ .source = source };
    defer yaml.deinit(allocator);

    try yaml.load(allocator);

    // Access parsed documents
    for (yaml.docs.items) |doc| {
        // Process document values
    }
}
```
