const std = @import("std");
const Parser = @import("parser.zig");
const Yaml = @import("yaml.zig");

/// Fuzz test entry point for LibFuzzer or AFL
/// This function is called repeatedly with different random inputs
export fn LLVMFuzzerTestOneInput(data: [*]const u8, size: usize) c_int {
    if (size == 0 or size > 1024 * 1024) return 0; // Skip empty or too large inputs

    const input = data[0..size];

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Try to parse the input
    var parser = Parser.init(allocator, input) catch return 0;
    defer parser.deinit(allocator);

    // Parse should either succeed or fail gracefully
    parser.parse(allocator) catch return 0;

    // If parsing succeeded, convert to tree
    var tree = parser.toOwnedTree(allocator) catch return 0;
    defer tree.deinit(allocator);

    return 0;
}

/// Standalone fuzz testing with random data generation
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var prng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    std.debug.print("Starting fuzz testing...\n", .{});

    var iterations: usize = 0;
    var failures: usize = 0;

    while (iterations < 10000) : (iterations += 1) {
        const size = random.intRangeAtMost(usize, 1, 1024);
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);

        // Generate random bytes
        random.bytes(input);

        // Try to parse
        var parser = Parser.init(allocator, input) catch {
            failures += 1;
            continue;
        };
        defer parser.deinit(allocator);

        parser.parse(allocator) catch {
            failures += 1;
            continue;
        };

        var tree = parser.toOwnedTree(allocator) catch {
            failures += 1;
            continue;
        };
        defer tree.deinit(allocator);

        if (iterations % 1000 == 0) {
            std.debug.print("Processed {} inputs, {} failures\n", .{ iterations, failures });
        }
    }

    std.debug.print("\nFuzz testing complete!\n", .{});
    std.debug.print("Total iterations: {}\n", .{iterations});
    std.debug.print("Total failures: {} ({d:.2}%)\n", .{ failures, @as(f64, @floatFromInt(failures)) / @as(f64, @floatFromInt(iterations)) * 100.0 });
}

test "fuzz with valid YAML patterns" {
    const patterns = [_][]const u8{
        "key: value",
        "list:\n  - item1\n  - item2",
        "nested:\n  key: value",
        "[1, 2, 3]",
        "a: 1\nb: 2",
        "foo: bar\nbaz: qux",
        "num: 42",
        "- a\n- b\n- c",
    };

    for (patterns) |pattern| {
        var parser = try Parser.init(std.testing.allocator, pattern);
        defer parser.deinit(std.testing.allocator);

        try parser.parse(std.testing.allocator);
        var tree = try parser.toOwnedTree(std.testing.allocator);
        defer tree.deinit(std.testing.allocator);
    }
}

test "fuzz with edge cases" {
    const edge_cases = [_][]const u8{
        "",
        " ",
        "\n",
        ":",
        "-",
        "[]",
        "{}",
        "'",
        "\"",
        "#",
        "...",
        "---",
    };

    for (edge_cases) |case| {
        var parser = Parser.init(std.testing.allocator, case) catch continue;
        defer parser.deinit(std.testing.allocator);

        _ = parser.parse(std.testing.allocator) catch continue;
    }
}

test "fuzz with malformed input" {
    const malformed = [_][]const u8{
        "key: : value",
        "- - - item",
        "unclosed: 'string",
        "bad\tindent: value",
        "key:: value",
        "---\n---\n---",
    };

    for (malformed) |input| {
        var parser = Parser.init(std.testing.allocator, input) catch continue;
        defer parser.deinit(std.testing.allocator);

        _ = parser.parse(std.testing.allocator) catch continue;
    }
}
