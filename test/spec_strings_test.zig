const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: String Edge Cases
// Tests various string quoting and escaping scenarios

test "spec: quoted strings preserve type" {
    const Data = struct {
        str1: []const u8,
        str2: []const u8,
        str3: []const u8,
    };

    const yaml =
        \\str1: "value1"
        \\str2: 'value2'
        \\str3: "text with spaces"
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value1", data.str1);
    try std.testing.expectEqualStrings("value2", data.str2);
    try std.testing.expectEqualStrings("text with spaces", data.str3);
}

test "spec: strings containing numbers" {
    const Data = struct {
        version: []const u8,
        code: []const u8,
        identifier: []const u8,
    };

    const yaml =
        \\version: "v2.3.4"
        \\code: 'abc123'
        \\identifier: "ID-456"
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("v2.3.4", data.version);
    try std.testing.expectEqualStrings("abc123", data.code);
    try std.testing.expectEqualStrings("ID-456", data.identifier);
}

test "spec: strings with special YAML characters" {
    const Data = struct {
        colon: []const u8,
        dash: []const u8,
        bracket: []const u8,
        brace: []const u8,
    };

    const yaml =
        \\colon: "key: value"
        \\dash: "- item"
        \\bracket: "[array]"
        \\brace: "{map}"
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("key: value", data.colon);
    try std.testing.expectEqualStrings("- item", data.dash);
    try std.testing.expectEqualStrings("[array]", data.bracket);
    try std.testing.expectEqualStrings("{map}", data.brace);
}

test "spec: double-quoted with escape sequences" {
    const Data = struct {
        newline: []const u8,
        tab: []const u8,
        quote: []const u8,
    };

    const yaml =
        \\newline: "line1\nline2"
        \\tab: "col1\tcol2"
        \\quote: "say \"hi\""
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("line1\nline2", data.newline);
    try std.testing.expectEqualStrings("col1\tcol2", data.tab);
    try std.testing.expectEqualStrings("say \"hi\"", data.quote);
}

test "spec: single-quoted with escaped quotes" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: 'can''t stop won''t stop'\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("can't stop won't stop", data.text);
}

test "spec: plain scalars requiring quotes" {
    const Data = struct {
        url: []const u8,
        email: []const u8,
        version: []const u8,
    };

    const yaml =
        \\url: "http://example.com"
        \\email: "user@example.com"
        \\version: "1.2.3"
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("http://example.com", data.url);
    try std.testing.expectEqualStrings("user@example.com", data.email);
    try std.testing.expectEqualStrings("1.2.3", data.version);
}

test "spec: single line plain scalar" {
    const Data = struct {
        description: []const u8,
    };

    const yaml = "description: This is a long description on a single line\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("This is a long description on a single line", data.description);
}

test "spec: empty quoted strings" {
    const Data = struct {
        single: []const u8,
        double: []const u8,
    };

    const yaml =
        \\single: ''
        \\double: ""
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("", data.single);
    try std.testing.expectEqualStrings("", data.double);
}

test "spec: strings with only spaces" {
    const Data = struct {
        spaces: []const u8,
    };

    const yaml = "spaces: '   '\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("   ", data.spaces);
}

test "spec: strings starting with special chars" {
    const Data = struct {
        at_sign: []const u8,
        backtick: []const u8,
        percent: []const u8,
    };

    const yaml =
        \\at_sign: "@username"
        \\backtick: "`code`"
        \\percent: "%value"
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("@username", data.at_sign);
    try std.testing.expectEqualStrings("`code`", data.backtick);
    try std.testing.expectEqualStrings("%value", data.percent);
}

test "spec: long strings without line breaks" {
    const Data = struct {
        long_text: []const u8,
    };

    var buf: [500]u8 = undefined;
    @memset(&buf, 'x');
    const expected = buf[0..];

    var yaml_buf: [520]u8 = undefined;
    const yaml = try std.fmt.bufPrint(&yaml_buf, "long_text: {s}\n", .{expected});

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(usize, 500), data.long_text.len);
}

test "spec: strings with trailing spaces preserved" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: 'value   '\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("value   ", data.text);
}

test "spec: strings with leading spaces preserved" {
    const Data = struct {
        text: []const u8,
    };

    const yaml = "text: '   value'\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqualStrings("   value", data.text);
}
