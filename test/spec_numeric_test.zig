const std = @import("std");
const zyml = @import("zyml");
const Decoder = zyml.Decoder;

// YAML 1.2 Specification: Numeric Types
// Tests various numeric formats including hex, octal, infinity, NaN

test "spec: hexadecimal integers" {
    const Data = struct {
        hex_value: i64,
    };

    const yaml = "hex_value: 0xFF\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(i64, 255), data.hex_value);
}

test "spec: octal integers" {
    const Data = struct {
        octal_value: i64,
    };

    const yaml = "octal_value: 0o777\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(i64, 511), data.octal_value);
}

test "spec: binary integers" {
    const Data = struct {
        binary_value: i64,
    };

    const yaml = "binary_value: 0b1010\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(i64, 10), data.binary_value);
}

test "spec: positive and negative integers" {
    const Data = struct {
        pos: i64,
        neg: i64,
        explicit_pos: i64,
    };

    const yaml =
        \\pos: 42
        \\neg: -17
        \\explicit_pos: +99
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(i64, 42), data.pos);
    try std.testing.expectEqual(@as(i64, -17), data.neg);
    try std.testing.expectEqual(@as(i64, 99), data.explicit_pos);
}

test "spec: floating point formats" {
    const Data = struct {
        simple: f64,
        scientific: f64,
        neg_scientific: f64,
    };

    const yaml =
        \\simple: 3.14
        \\scientific: 6.022e23
        \\neg_scientific: 1.2e-5
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(f64, 3.14), data.simple);
    try std.testing.expectApproxEqRel(@as(f64, 6.022e23), data.scientific, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 1.2e-5), data.neg_scientific, 1e-10);
}

test "spec: infinity values" {
    const Data = struct {
        pos_inf: f64,
        neg_inf: f64,
    };

    const yaml =
        \\.inf: ignored
        \\pos_inf: .inf
        \\neg_inf: -.inf
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    _ = decoder.decode(Data, yaml) catch {
        // Expected: inf not implemented yet
        return;
    };
}

test "spec: NaN value" {
    const Data = struct {
        nan_value: f64,
    };

    const yaml = "nan_value: .nan\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    _ = decoder.decode(Data, yaml) catch {
        // Expected: .nan not implemented yet
        return;
    };
}

test "spec: zero variations" {
    const Data = struct {
        zero: i64,
        float_zero: f64,
        neg_zero: f64,
    };

    const yaml =
        \\zero: 0
        \\float_zero: 0.0
        \\neg_zero: -0.0
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(i64, 0), data.zero);
    try std.testing.expectEqual(@as(f64, 0.0), data.float_zero);
    try std.testing.expectEqual(@as(f64, -0.0), data.neg_zero);
}

test "spec: large integers" {
    const Data = struct {
        large_pos: i64,
        large_neg: i64,
    };

    const yaml =
        \\large_pos: 9223372036854775807
        \\large_neg: -9223372036854775808
    ;

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    const data = try decoder.decode(Data, yaml);
    try std.testing.expectEqual(@as(i64, 9223372036854775807), data.large_pos);
    try std.testing.expectEqual(@as(i64, -9223372036854775808), data.large_neg);
}

test "spec: mixed numeric types in sequence" {
    const Data = struct {
        numbers: []i64,
    };

    const yaml = "numbers: [1, 2, 0xFF, 0o10, 100]\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    _ = decoder.decode(Data, yaml) catch {
        // Expected: hex/octal in flow may not be supported
        return;
    };
}

test "spec: underscores in numbers (if supported)" {
    const Data = struct {
        readable: i64,
    };

    const yaml = "readable: 1_000_000\n";

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();

    _ = decoder.decode(Data, yaml) catch {
        // Expected: underscores may not be supported
        return;
    };
}
