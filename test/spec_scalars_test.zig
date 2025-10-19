const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Scalars
// Tests various scalar representations

test "spec: plain scalars" {
    const Data = struct {
        string: []const u8,
        number: i64,
        negative: i64,
        float_val: f64,
    };

    const yaml =
        \\string: hello world
        \\number: 123
        \\negative: -456
        \\float_val: 3.14
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("hello world", data.string);
    try std.testing.expectEqual(@as(i64, 123), data.number);
    try std.testing.expectEqual(@as(i64, -456), data.negative);
    try std.testing.expectEqual(@as(f64, 3.14), data.float_val);
}

test "spec: single-quoted scalars" {
    const Data = struct {
        simple: []const u8,
        with_spaces: []const u8,
        with_quotes: []const u8,
    };

    const yaml =
        \\simple: 'hello'
        \\with_spaces: 'hello world'
        \\with_quotes: 'it''s working'
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("hello", data.simple);
    try std.testing.expectEqualStrings("hello world", data.with_spaces);
    try std.testing.expectEqualStrings("it's working", data.with_quotes);
}

test "spec: double-quoted scalars" {
    const Data = struct {
        simple: []const u8,
        with_newline: []const u8,
        with_tab: []const u8,
        with_quote: []const u8,
    };

    const yaml =
        \\simple: "hello"
        \\with_newline: "line1\nline2"
        \\with_tab: "col1\tcol2"
        \\with_quote: "quote: \"value\""
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("hello", data.simple);
    try std.testing.expectEqualStrings("line1\nline2", data.with_newline);
    try std.testing.expectEqualStrings("col1\tcol2", data.with_tab);
    try std.testing.expectEqualStrings("quote: \"value\"", data.with_quote);
}

test "spec: boolean values" {
    const Data = struct {
        bool_true: bool,
        bool_false: bool,
    };

    const yaml =
        \\bool_true: true
        \\bool_false: false
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(true, data.bool_true);
    try std.testing.expectEqual(false, data.bool_false);
}

test "spec: numeric types" {
    const Data = struct {
        int_decimal: i64,
        int_negative: i64,
        float_decimal: f64,
        float_negative: f64,
        float_exp: f64,
    };

    const yaml =
        \\int_decimal: 42
        \\int_negative: -17
        \\float_decimal: 3.14159
        \\float_negative: -2.5
        \\float_exp: 1.5e3
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqual(@as(i64, 42), data.int_decimal);
    try std.testing.expectEqual(@as(i64, -17), data.int_negative);
    try std.testing.expectEqual(@as(f64, 3.14159), data.float_decimal);
    try std.testing.expectEqual(@as(f64, -2.5), data.float_negative);
    try std.testing.expectEqual(@as(f64, 1500.0), data.float_exp);
}

test "spec: empty string value" {
    const Data = struct {
        empty: []const u8,
        present: []const u8,
    };

    const yaml =
        \\empty: ''
        \\present: value
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("", data.empty);
    try std.testing.expectEqualStrings("value", data.present);
}

test "spec: multi-word plain scalars" {
    const Data = struct {
        sentence: []const u8,
        path: []const u8,
    };

    const yaml =
        \\sentence: this is a sentence
        \\path: /usr/local/bin
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("this is a sentence", data.sentence);
    try std.testing.expectEqualStrings("/usr/local/bin", data.path);
}

test "spec: scalars with special characters" {
    const Data = struct {
        colon_in_value: []const u8,
        hash_quoted: []const u8,
        at_sign: []const u8,
    };

    const yaml =
        \\colon_in_value: "http://example.com"
        \\hash_quoted: "#hashtag"
        \\at_sign: "@username"
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decodeFromSlice(Data, yaml);
    try std.testing.expectEqualStrings("http://example.com", data.colon_in_value);
    try std.testing.expectEqualStrings("#hashtag", data.hash_quoted);
    try std.testing.expectEqualStrings("@username", data.at_sign);
}
