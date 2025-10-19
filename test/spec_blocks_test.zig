const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Block Scalars
// Tests literal (|) and folded (>) block scalars

test "spec: literal block scalar" {
    const Data = struct {
        text: []const u8,
    };

    const yaml =
        \\text: |
        \\  Line 1
        \\  Line 2
        \\  Line 3
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "Line 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "Line 2") != null);
}

test "spec: folded block scalar" {
    const Data = struct {
        text: []const u8,
    };

    const yaml =
        \\text: >
        \\  This is a long line
        \\  that will be folded
        \\  into a single line.
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    // Folded blocks should join lines with spaces
    const trimmed = std.mem.trimRight(u8, data.text, "\n");
    try std.testing.expect(std.mem.indexOf(u8, trimmed, "\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "This is") != null);
}

test "spec: literal block with empty lines" {
    const Data = struct {
        text: []const u8,
    };

    const yaml =
        \\text: |
        \\  First paragraph
        \\
        \\  Second paragraph
        \\
        \\  Third paragraph
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "First paragraph") != null);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "Second paragraph") != null);
}

test "spec: multiple block scalars" {
    const Data = struct {
        description: []const u8,
        notes: []const u8,
    };

    const yaml =
        \\description: |
        \\  This is the description.
        \\  It has multiple lines.
        \\notes: >
        \\  These are notes
        \\  that will be folded.
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expect(std.mem.indexOf(u8, data.description, "description") != null);
    try std.testing.expect(std.mem.indexOf(u8, data.notes, "notes") != null);
}

test "spec: block scalar in nested structure" {
    const Config = struct {
        server: struct {
            description: []const u8,
            port: i64,
        },
    };

    const yaml =
        \\server:
        \\  description: |
        \\    Multi-line server
        \\    description here.
        \\  port: 8080
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Config, yaml);
    try std.testing.expect(std.mem.indexOf(u8, data.server.description, "Multi-line") != null);
    try std.testing.expectEqual(@as(i64, 8080), data.server.port);
}

test "spec: block scalar with indentation" {
    const Data = struct {
        code: []const u8,
    };

    const yaml =
        \\code: |
        \\  function hello() {
        \\      console.log("Hello");
        \\  }
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expect(std.mem.indexOf(u8, data.code, "function") != null);
    try std.testing.expect(std.mem.indexOf(u8, data.code, "console.log") != null);
}

test "spec: literal vs folded comparison" {
    const Data = struct {
        literal: []const u8,
        folded: []const u8,
    };

    const yaml =
        \\literal: |
        \\  Line 1
        \\  Line 2
        \\folded: >
        \\  Line 1
        \\  Line 2
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);

    // Literal should preserve newlines
    try std.testing.expect(std.mem.indexOf(u8, data.literal, "\n") != null);

    // Folded should join lines (trimming trailing newline)
    const folded_trimmed = std.mem.trimRight(u8, data.folded, "\n");
    try std.testing.expect(std.mem.indexOf(u8, folded_trimmed, "\n") == null);
}

test "spec: block scalar after regular values" {
    const Data = struct {
        name: []const u8,
        version: []const u8,
        changelog: []const u8,
    };

    const yaml =
        \\name: MyApp
        \\version: 1.0.0
        \\changelog: |
        \\  Version 1.0.0
        \\  - Initial release
        \\  - Added feature X
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("MyApp", data.name);
    try std.testing.expectEqualStrings("1.0.0", data.version);
    try std.testing.expect(std.mem.indexOf(u8, data.changelog, "Initial release") != null);
}

test "spec: block scalar with strip chomping (|-)" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: |-\n  line1\n  line2\n\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    // Strip should remove all trailing newlines
    try std.testing.expectEqualStrings("line1\nline2", data.text);
}

test "spec: block scalar with keep chomping (|+)" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: |+\n  line1\n  line2\n\n\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    // Keep should preserve all trailing newlines
    try std.testing.expect(std.mem.endsWith(u8, data.text, "\n\n\n"));
}

test "spec: block scalar with explicit indentation (|2)" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: |2\n  line1\n  line2\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "line1") != null);
    try std.testing.expect(std.mem.indexOf(u8, data.text, "line2") != null);
}

test "spec: folded block with strip chomping (>-)" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: >-\n  line1\n  line2\n\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    const trimmed = std.mem.trimRight(u8, data.text, " ");
    // Folded with strip should have no trailing newlines
    try std.testing.expect(!std.mem.endsWith(u8, trimmed, "\n"));
}

test "spec: block scalar combined indicators (|2-)" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: |2-\n  line1\n  line2\n\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    // Should combine explicit indent with strip chomping
    try std.testing.expectEqualStrings("line1\nline2", data.text);
}
