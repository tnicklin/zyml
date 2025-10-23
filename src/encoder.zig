const std = @import("std");
const Allocator = std.mem.Allocator;
const Yaml = @import("yaml.zig");

pub const Encoder = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) Encoder {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Encoder) void {
        self.arena.deinit();
    }

    fn encodeValue(self: *Encoder, value: anytype) !Yaml.Value {
        const arena_allocator = self.arena.allocator();
        return try Yaml.Value.encode(arena_allocator, value) orelse error.CannotEncodeValue;
    }

    pub fn encode(self: *Encoder, value: anytype) ![]const u8 {
        const yaml_value = try self.encodeValue(value);

        var list: std.ArrayListUnmanaged(u8) = .empty;
        defer list.deinit(self.allocator);

        try yaml_value.toString(list.writer(self.allocator), .{});

        return try list.toOwnedSlice(self.allocator);
    }

    pub fn encodeToWriter(self: *Encoder, writer: anytype, value: anytype) !void {
        const yaml_value = try self.encodeValue(value);
        try yaml_value.toString(writer, .{});
    }

    pub fn encodeToFile(self: *Encoder, path: []const u8, value: anytype) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const yaml_str = try self.encode(value);
        defer self.allocator.free(yaml_str);

        try file.writeAll(yaml_str);
    }

    pub fn encodeAll(self: *Encoder, values: anytype) ![]const u8 {
        var list: std.ArrayListUnmanaged(u8) = .empty;
        defer list.deinit(self.allocator);

        const writer = list.writer(self.allocator);

        inline for (values) |value| {
            try writer.writeAll("---\n");

            const yaml_value = try self.encodeValue(value);
            try yaml_value.toString(writer, .{});
            try writer.writeByte('\n');
        }

        try writer.writeAll("...\n");

        return try list.toOwnedSlice(self.allocator);
    }
};

pub fn encode(allocator: Allocator, value: anytype) !struct { yaml: []const u8, arena: std.heap.ArenaAllocator } {
    var encoder = Encoder.init(allocator);
    errdefer encoder.deinit();

    const yaml_str = try encoder.encode(value);

    return .{ .yaml = yaml_str, .arena = encoder.arena };
}

pub fn encodeToFile(allocator: Allocator, path: []const u8, value: anytype) !void {
    var encoder = Encoder.init(allocator);
    defer encoder.deinit();

    try encoder.encodeToFile(path, value);
}
