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

    pub fn encode(self: *Encoder, value: anytype) ![]const u8 {
        const arena_allocator = self.arena.allocator();

        const yaml_value = try Yaml.Value.encode(arena_allocator, value) orelse {
            return error.CannotEncodeValue;
        };

        var list: std.ArrayListUnmanaged(u8) = .empty;
        defer list.deinit(self.allocator);

        try yaml_value.toString(list.writer(self.allocator), .{});

        return try list.toOwnedSlice(self.allocator);
    }

    pub fn encodeToWriter(self: *Encoder, writer: anytype, value: anytype) !void {
        const arena_allocator = self.arena.allocator();

        const yaml_value = try Yaml.Value.encode(arena_allocator, value) orelse {
            return error.CannotEncodeValue;
        };

        try yaml_value.toString(writer, .{});
    }

    pub fn encodeToFile(self: *Encoder, path: []const u8, value: anytype) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Encode to string first
        const yaml_str = try self.encode(value);
        defer self.allocator.free(yaml_str);

        // Write to file
        try file.writeAll(yaml_str);
    }

    pub fn encodeAll(self: *Encoder, values: anytype) ![]const u8 {
        const arena_allocator = self.arena.allocator();

        var list: std.ArrayListUnmanaged(u8) = .empty;
        defer list.deinit(self.allocator);

        const writer = list.writer(self.allocator);

        inline for (values) |value| {
            try writer.writeAll("---\n");

            const yaml_value = try Yaml.Value.encode(arena_allocator, value) orelse {
                return error.CannotEncodeValue;
            };

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
