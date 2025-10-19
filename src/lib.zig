const std = @import("std");

pub const Parser = @import("parser.zig");
pub const Tokenizer = @import("tokenizer.zig");
pub const Tree = @import("tree.zig");
pub const Yaml = @import("yaml.zig");

pub const Value = Yaml.Value;
pub const List = Yaml.List;
pub const Map = Yaml.Map;

// Decoder API
pub const Decoder = @import("decoder.zig").Decoder;
pub const decode = @import("decoder.zig").decode;
pub const decodeFromFile = @import("decoder.zig").decodeFromFile;
pub const decodeFromReader = @import("decoder.zig").decodeFromReader;

pub fn toString(gpa: std.mem.Allocator, input: anytype, writer: anytype) Yaml.ToStringError!void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const maybe_value = try Yaml.Value.encode(arena.allocator(), input);

    if (maybe_value) |value| {
        try value.toString(writer, .{});
    }
}
